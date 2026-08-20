import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class LlmException implements Exception {
  LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LlmToolCall {
  const LlmToolCall({required this.id, required this.name, required this.argumentsJson});
  final String id;
  final String name;
  final String argumentsJson;
}

class LlmResponse {
  const LlmResponse({this.content, this.toolCalls = const []});
  final String? content;
  final List<LlmToolCall> toolCalls;
  bool get hasToolCalls => toolCalls.isNotEmpty;
}

class LlmClient {
  LlmClient({required this.baseUrl, required this.apiKey, required this.model, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final String model;
  final http.Client _http;

  Future<LlmResponse> chat({
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
  }) async {
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$root/chat/completions');
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'tools': tools,
      'tool_choice': 'auto',
      'temperature': 0.2,
    };
    try {
      final response = await _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LlmException('DeepSeek HTTP ${response.statusCode}: ${response.body}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw LlmException('Unexpected DeepSeek response');
      }
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        throw LlmException('DeepSeek returned no choices');
      }
      final message = (choices.first as Map)['message'];
      if (message is! Map) throw LlmException('DeepSeek returned no message');
      final toolCallsRaw = message['tool_calls'];
      final calls = <LlmToolCall>[];
      if (toolCallsRaw is List) {
        for (final call in toolCallsRaw) {
          if (call is! Map) continue;
          final function = call['function'];
          if (function is! Map) continue;
          calls.add(
            LlmToolCall(
              id: call['id']?.toString() ?? '',
              name: function['name']?.toString() ?? '',
              argumentsJson: function['arguments']?.toString() ?? '{}',
            ),
          );
        }
      }
      return LlmResponse(content: message['content']?.toString(), toolCalls: calls);
    } on TimeoutException {
      throw LlmException('DeepSeek timed out. Try again.');
    } on LlmException {
      rethrow;
    } catch (error) {
      throw LlmException('DeepSeek request failed: $error');
    }
  }
}
