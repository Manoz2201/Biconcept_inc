import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/appwrite/appwrite_client.dart';
import '../data/settings_store.dart';
import 'agent_service.dart';

/// Runs Workers AI through Appwrite so Flutter web is not blocked by CORS.
WorkersAiTransport appwriteWorkersAiTransport({
  required String accountId,
  required String apiToken,
}) {
  final cleanAccount = sanitizeCloudflareAccountId(accountId);
  final cleanToken = sanitizeCloudflareApiToken(apiToken);
  return (model, payload) async {
    try {
      final execution = await AppwriteService.functions.createExecution(
        functionId: AppwriteService.workersAiProxyFn,
        body: jsonEncode({
          'accountId': cleanAccount,
          'apiToken': cleanToken,
          'model': model,
          'payload': payload,
        }),
      );
      final raw = execution.responseBody;
      if (raw.isEmpty) {
        throw AgentException(
          'Workers AI proxy returned an empty response. Deploy the workers-ai-proxy function, then try again.',
        );
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw AgentException('Workers AI proxy returned an unexpected payload.');
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map['error'] != null && map['body'] == null) {
        final code = map['error'].toString();
        if (code == 'api_token_required' || code == 'invalid_account_id') {
          throw AgentException(
            'Workers AI is not configured. Add CLOUDFLARE_ACCOUNT_ID and '
            'CLOUDFLARE_API_TOKEN as GitHub secrets, run the Appwrite workflow, '
            'or paste them in Settings.',
          );
        }
        throw AgentException(
          'Workers AI proxy: ${map['error']}${map['details'] == null ? '' : ' (${map['details']})'}.',
        );
      }
      final status = (map['status'] as num?)?.toInt() ?? execution.responseStatusCode;
      final body = map['body'];
      return WorkersAiResponse(
        statusCode: status == 0 ? 500 : status,
        body: body == null ? raw : jsonEncode(body),
      );
    } on AgentException {
      rethrow;
    } on AppwriteException catch (error) {
      throw AgentException(
        'Could not run the Workers AI proxy (${error.message ?? error.code}). '
        'Deploy functions/workers-ai-proxy or use the Windows app.',
      );
    }
  };
}

/// Checks a pasted token, or the function env token when [apiToken] is empty.
Future<String> verifyWorkersAiToken({required String apiToken}) async {
  final token = sanitizeCloudflareApiToken(apiToken);
  if (token.isEmpty || kIsWeb) return _verifyViaProxy(token);
  return _verifyDirect(token);
}

Future<String> _verifyViaProxy(String apiToken) async {
  try {
    final execution = await AppwriteService.functions.createExecution(
      functionId: AppwriteService.workersAiProxyFn,
      body: jsonEncode({
        'action': 'verify',
        'accountId': '00000000000000000000000000000000',
        'apiToken': apiToken,
      }),
    );
    return _verifyMessageFromBody(execution.responseBody, fallbackStatus: execution.responseStatusCode);
  } on AppwriteException catch (error) {
    return 'Could not verify (${error.message ?? error.code}). Deploy workers-ai-proxy and try again.';
  }
}

Future<String> _verifyDirect(String apiToken) async {
  try {
    final response = await http.get(
      Uri.parse('https://api.cloudflare.com/client/v4/user/tokens/verify'),
      headers: {
        'Authorization': 'Bearer $apiToken',
        'Accept': 'application/json',
      },
    );
    return _verifyMessageFromBody(response.body, fallbackStatus: response.statusCode);
  } catch (error) {
    return 'Could not reach Cloudflare ($error).';
  }
}

String _verifyMessageFromBody(String raw, {required int fallbackStatus}) {
  if (raw.isEmpty) return 'Could not reach Cloudflare to verify the token.';
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    if (fallbackStatus == 401) {
      return 'Token was rejected. Create a new Workers AI API Token and paste the full value.';
    }
    return 'Cloudflare returned HTTP $fallbackStatus.';
  }
  if (decoded is! Map) return 'Unexpected verify response.';
  final map = Map<String, dynamic>.from(decoded);
  if (map['error'] != null && map['body'] == null) {
    final code = map['error'].toString();
    if (code == 'api_token_required') {
      return 'No token in Settings and no CLOUDFLARE_API_TOKEN on workers-ai-proxy yet.';
    }
    return 'Proxy error: ${map['error']}';
  }
  final status = (map['status'] as num?)?.toInt() ?? fallbackStatus;
  final body = map['body'] is Map ? Map<String, dynamic>.from(map['body'] as Map) : map;
  final success = body['success'] == true;
  if (status == 200 && success) return 'Token is valid.';
  if (status == 401 || body.toString().contains('Authentication error')) {
    return 'Token was rejected. Create a new Workers AI API Token (not the Global API Key) and paste the full value.';
  }
  return 'Cloudflare returned HTTP $status.';
}
