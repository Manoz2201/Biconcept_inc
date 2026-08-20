import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Primary and fallback Workers AI instruction models.
const kWorkersAiPrimaryModel = '@cf/meta/llama-3.2-3b-instruct';
const kWorkersAiFallbackModel = '@cf/mistral/mistral-7b-instruct-v0.2';
const kWorkersAiHost = 'api.cloudflare.com';

/// Builds the Workers AI run URL.
///
/// Model ids like `@cf/meta/llama-3.2-3b-instruct` must keep `/` as path
/// separators. Encoding the whole id (`%2F`) makes Cloudflare return
/// HTTP 400 / code 7000 "No route for that URI".
Uri workersAiRunUri({required String accountId, required String model}) {
  return Uri(
    scheme: 'https',
    host: kWorkersAiHost,
    pathSegments: [
      'client',
      'v4',
      'accounts',
      accountId.trim(),
      'ai',
      'run',
      for (final part in model.split('/'))
        if (part.isNotEmpty) part,
    ],
  );
}
const _ddgHost = 'api.duckduckgo.com';
const _wikiHost = 'en.wikipedia.org';
const _maxToolIterations = 8;
const _requestTimeout = Duration(seconds: 60);
const _fetchTimeout = Duration(seconds: 20);
const _fetchMaxBytes = 120000;
const _fetchMaxChars = 8000;

const _systemPrompt = '''
You are Manoj Singharya, the in-app operator for BiConcept (interior estimates, CRM, calendar, accounts).
You are not limited to estimating. Use tools to search the internet, read live pages, query the Appwrite database, and do anything in the app the user asks: clients, estimates, calendar, payments, rate card, company profile, navigation, and quotations.

If a tool is needed, respond ONLY with a JSON object (no markdown, no extra text):
{"tool_call": {"name": "tool_name", "arguments": {}}}

Quote every key and every string value. Example:
{"tool_call": {"name": "get_client", "arguments": {"name": "ABC"}}}

Never show tool_call JSON to the user. After a tool result, answer in plain language.

Built-in internet tools:
1. web_search — arguments: {"query": "<search string>"}
2. web_fetch — arguments: {"url": "https://..."}  (http/https only; returns page text)

Scratch notes (session only):
3. app_action — arguments: {"action": "create_note"|"get_notes"|"delete_note", "params": {}}

All other tool names come from the extra system prompt (CRM, calendar, accounts, catalog, estimates, query_database, sync_cloud, navigate, …). Call those the same way.

If no tool is needed, answer in plain text. Do not wrap a normal answer in JSON.
Never invent catalog unit rates or GST. Look them up with tools. Amounts are INR.
The user may attach PDF, Word (.docx), and Excel (.xlsx). Read and summarize those files from session context. Keep using earlier chat turns in this session.
''';

/// Thrown when the Cloudflare or tool HTTP layer fails.
class AgentException implements Exception {
  AgentException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cloudflare Workers AI client with a JSON tool-calling loop.
///
/// Calls `POST /accounts/{accountId}/ai/run/{model}` and, when the model
/// replies with `{"tool_call": ...}`, runs internet/app tools then continues
/// (max [_maxToolIterations] model calls).
class AgentService {
  /// Optional catalog/app tool runner used by Manoj for BiConcept actions.
  Future<String> Function(String name, Map<String, dynamic> arguments)? onAppTool;

  /// Extra system instructions (catalog tools, quotation rules, etc.).
  String extraSystem;

  AgentService({
    required this.accountId,
    required this.apiToken,
    this.onAppTool,
    this.extraSystem = '',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String accountId;
  final String apiToken;
  final http.Client _http;

  /// In-memory notes used by the mock [app_action] tool.
  final List<Map<String, dynamic>> _notes = [];
  int _nextNoteId = 1;

  /// Sends [userMessage] through the tool loop and returns the final reply.
  ///
  /// [extraUserContext] is prepended as app snapshot JSON for catalog tools.
  /// [history] is prior user/assistant turns from the local session cache.
  Future<String> chat(
    String userMessage, {
    String extraUserContext = '',
    List<Map<String, String>> history = const [],
  }) async {
    final text = userMessage.trim();
    if (text.isEmpty) return 'Please enter a message.';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _fullSystemPrompt()},
      for (final turn in history)
        if ((turn['role'] == 'user' || turn['role'] == 'assistant') &&
            (turn['content']?.trim().isNotEmpty ?? false))
          {'role': turn['role']!, 'content': turn['content']!},
      {
        'role': 'user',
        'content': extraUserContext.trim().isEmpty
            ? text
            : 'App context:\n$extraUserContext\n\n$text',
      },
    ];

    try {
      for (var step = 0; step < _maxToolIterations; step++) {
        final reply = await _runModel(messages);
        final toolCall = parseAgentToolCall(reply);

        if (toolCall == null) {
          if (agentLooksLikeToolCall(reply) && step + 1 < _maxToolIterations) {
            messages.add({'role': 'assistant', 'content': reply});
            messages.add({
              'role': 'user',
              'content':
                  'That was not valid tool JSON and must not be shown to the user. '
                  'Reply with only {"tool_call":{"name":"...","arguments":{...}}} '
                  'or a plain-language answer.',
            });
            continue;
          }
          final answer = reply.trim();
          return answer.isEmpty ? 'The model returned an empty response.' : answer;
        }

        final toolResult = await _executeTool(toolCall);
        messages.add({'role': 'assistant', 'content': reply});
        messages.add({
          'role': 'user',
          'content': 'Tool result (do not mention this wrapper; use it to answer):\n$toolResult',
        });
      }

      return 'Reached the tool-call limit without a final answer. Try a simpler request.';
    } on AgentException catch (error) {
      return error.message;
    } on SocketException catch (error) {
      return 'Network error: ${error.message}';
    } on TimeoutException {
      return 'The request timed out. Try again.';
    } on FormatException catch (error) {
      return 'Invalid JSON: ${error.message}';
    } on http.ClientException catch (error) {
      return 'Network error: $error';
    } catch (error) {
      return 'Unexpected error: $error';
    }
  }

  /// DuckDuckGo + Wikipedia search, usable from catalog/app tools too.
  Future<String> runWebSearch(String query) => _webSearch(query);

  /// Fetch an http(s) page as plain text.
  Future<String> runWebFetch(String url) => _webFetch(url);

  String _fullSystemPrompt() {
    final extra = extraSystem.trim();
    if (extra.isEmpty) return _systemPrompt;
    return '$_systemPrompt\n\n$extra';
  }

  /// Runs the primary model, then the fallback if Cloudflare rejects the call.
  Future<String> _runModel(List<Map<String, String>> messages) async {
    try {
      return await _postRun(kWorkersAiPrimaryModel, messages);
    } on AgentException catch (primary) {
      try {
        return await _postRun(kWorkersAiFallbackModel, messages);
      } on AgentException catch (fallback) {
        throw AgentException('${primary.message}\nFallback: ${fallback.message}');
      }
    }
  }

  Future<String> _postRun(String model, List<Map<String, String>> messages) async {
    final uri = workersAiRunUri(accountId: accountId, model: model);

    late final http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'messages': messages,
              'temperature': 0.2,
              'max_tokens': 768,
              'stream': false,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw AgentException('Cloudflare Workers AI timed out ($model).');
    } on SocketException catch (error) {
      throw AgentException('Could not reach Cloudflare: ${error.message}');
    } on http.ClientException catch (error) {
      throw AgentException('Could not reach Cloudflare: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AgentException(
        'Cloudflare Workers AI HTTP ${response.statusCode} ($model): ${_shortBody(response.body)}',
      );
    }

    final decoded = _decodeJsonMap(response.body, source: 'Cloudflare Workers AI');
    final success = decoded['success'];
    if (success is bool && !success) {
      throw AgentException(
        'Cloudflare Workers AI error ($model): ${_cloudflareErrors(decoded)}',
      );
    }

    final result = decoded['result'];
    if (result is String && result.trim().isNotEmpty) return result;
    if (result is Map) {
      final content = result['response'] ?? result['text'] ?? result['output'];
      if (content != null && content.toString().trim().isNotEmpty) {
        return content.toString();
      }
    }

    throw AgentException('Cloudflare Workers AI returned no text ($model).');
  }

  Future<String> _executeTool(Map<String, dynamic> toolCall) async {
    final name = toolCall['name']?.toString().trim() ?? '';
    final arguments = _asStringKeyedMap(toolCall['arguments']);

    switch (name) {
      case 'web_search':
        final query = arguments['query']?.toString().trim() ?? '';
        if (query.isEmpty) return 'web_search failed: "query" is required.';
        return _webSearch(query);
      case 'web_fetch':
        final url = (arguments['url'] ?? arguments['uri'] ?? arguments['link'])?.toString().trim() ?? '';
        if (url.isEmpty) return 'web_fetch failed: "url" is required.';
        return _webFetch(url);
      case 'app_action':
        final action = arguments['action']?.toString().trim() ?? '';
        final params = _asStringKeyedMap(arguments['params']);
        return _appAction(action, params);
      default:
        final handler = onAppTool;
        if (handler != null) {
          return handler(name, arguments);
        }
        return 'Unknown tool "$name". Use web_search, web_fetch, or an app/database tool from the system prompt.';
    }
  }

  /// DuckDuckGo Instant Answer API → short text summary.
  Future<String> _webSearch(String query) async {
    final uri = Uri.https(_ddgHost, '/', {
      'q': query,
      'format': 'json',
      'no_html': '1',
      'skip_disambig': '1',
    });

    late final http.Response response;
    try {
      response = await _http.get(uri, headers: {'Accept': 'application/json'}).timeout(_requestTimeout);
    } on TimeoutException {
      return 'web_search timed out for "$query".';
    } on SocketException catch (error) {
      return 'web_search network error: ${error.message}';
    } on http.ClientException catch (error) {
      return 'web_search network error: $error';
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return 'web_search HTTP ${response.statusCode}: ${_shortBody(response.body)}';
    }

    String ddg = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        ddg = _summarizeDuckDuckGo(query, Map<String, dynamic>.from(decoded));
      } else {
        ddg = 'web_search returned invalid JSON.';
      }
    } on FormatException catch (error) {
      ddg = 'web_search invalid JSON: ${error.message}';
    }

    if (!_isThinSearch(ddg)) return ddg;

    final wiki = await _wikipediaSearch(query);
    if (wiki == null) return ddg;
    return '$ddg\n\n$wiki';
  }

  bool _isThinSearch(String summary) {
    final text = summary.trim();
    return text.isEmpty || text.startsWith('No DuckDuckGo') || text.contains('invalid JSON');
  }

  Future<String?> _wikipediaSearch(String query) async {
    final uri = Uri.https(_wikiHost, '/w/api.php', {
      'action': 'opensearch',
      'search': query,
      'limit': '5',
      'namespace': '0',
      'format': 'json',
    });
    try {
      final response = await _http
          .get(uri, headers: {'Accept': 'application/json', 'User-Agent': 'BiConcept/1.0'})
          .timeout(_fetchTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.length < 4) return null;
      final titles = decoded[1];
      final snippets = decoded[2];
      final urls = decoded[3];
      if (titles is! List || titles.isEmpty) return null;
      final lines = <String>[];
      for (var i = 0; i < titles.length && i < 5; i++) {
        final title = titles[i];
        final snippet = snippets is List && i < snippets.length ? snippets[i] : '';
        final url = urls is List && i < urls.length ? urls[i] : '';
        lines.add('- $title${snippet.toString().trim().isEmpty ? '' : ': $snippet'} ($url)');
      }
      if (lines.isEmpty) return null;
      return 'Wikipedia for "$query":\n${lines.join('\n')}';
    } catch (_) {
      return null;
    }
  }

  /// Fetches an http(s) page and returns stripped text.
  Future<String> _webFetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'web_fetch failed: only http/https URLs are allowed.';
    }
    if (uri.host.isEmpty) return 'web_fetch failed: URL host is missing.';

    late final http.Response response;
    try {
      response = await _http
          .get(
            uri,
            headers: {
              'Accept': 'text/html,application/json,text/plain;q=0.9,*/*;q=0.8',
              'User-Agent': 'BiConcept/1.0 (Manoj Singharya)',
            },
          )
          .timeout(_fetchTimeout);
    } on TimeoutException {
      return 'web_fetch timed out for $url.';
    } on SocketException catch (error) {
      return 'web_fetch network error: ${error.message}';
    } on http.ClientException catch (error) {
      return 'web_fetch network error: $error';
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return 'web_fetch HTTP ${response.statusCode}: ${_shortBody(response.body)}';
    }
    if (response.bodyBytes.length > _fetchMaxBytes) {
      return 'web_fetch skipped: response larger than $_fetchMaxBytes bytes.';
    }

    final contentType = response.headers['content-type'] ?? '';
    final body = response.body;
    if (contentType.contains('application/json') || body.trim().startsWith('{') || body.trim().startsWith('[')) {
      return 'Fetched $url (JSON):\n${_shortBody(body, max: _fetchMaxChars)}';
    }
    final text = agentPlainTextFromHtml(body);
    if (text.isEmpty) return 'web_fetch: no readable text at $url.';
    return 'Fetched $url:\n$text';
  }

  String _summarizeDuckDuckGo(String query, Map<String, dynamic> json) {
    final parts = <String>[];
    void add(String? value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) parts.add(text);
    }

    add(json['Heading']?.toString());
    add(json['AbstractText']?.toString());
    add(json['Abstract']?.toString());
    add(json['Answer']?.toString());
    add(json['Definition']?.toString());

    final related = json['RelatedTopics'];
    if (related is List) {
      var taken = 0;
      for (final item in related) {
        if (taken >= 3) break;
        if (item is Map && item['Text'] != null) {
          parts.add('- ${item['Text']}');
          taken++;
        }
      }
    }

    if (parts.isEmpty) {
      return 'No DuckDuckGo instant-answer results for "$query".';
    }
    return 'Search results for "$query":\n${parts.join('\n')}';
  }

  /// Mock in-app notes. Returns a string describing what ran.
  String _appAction(String action, Map<String, dynamic> params) {
    switch (action) {
      case 'create_note':
        final title = params['title']?.toString().trim() ?? '';
        final body = (params['body'] ?? params['content'] ?? params['text'])?.toString() ?? '';
        if (title.isEmpty) {
          return 'app_action create_note failed: "title" is required.';
        }
        final note = {'id': _nextNoteId++, 'title': title, 'body': body};
        _notes.add(note);
        return 'Executed app_action create_note: id=${note['id']} title="$title".';
      case 'get_notes':
        if (_notes.isEmpty) return 'Executed app_action get_notes: no notes stored.';
        final list = _notes.map((note) => '${note['id']}: ${note['title']} — ${note['body']}').join('\n');
        return 'Executed app_action get_notes:\n$list';
      case 'delete_note':
        final id = int.tryParse(params['id']?.toString() ?? '');
        final title = params['title']?.toString().trim() ?? '';
        final before = _notes.length;
        _notes.removeWhere((note) {
          if (id != null) return note['id'] == id;
          if (title.isNotEmpty) return note['title'] == title;
          return false;
        });
        if (id == null && title.isEmpty) {
          return 'app_action delete_note failed: pass "id" or "title".';
        }
        final removed = before - _notes.length;
        return 'Executed app_action delete_note: removed $removed note(s).';
      default:
        return 'Unknown app_action "$action". Use create_note, get_notes, or delete_note.';
    }
  }

  Map<String, dynamic> _decodeJsonMap(String body, {required String source}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw FormatException('$source response is not a JSON object');
    } on FormatException catch (error) {
      throw AgentException('Invalid JSON from $source: ${error.message}');
    }
  }

  String _cloudflareErrors(Map<String, dynamic> json) {
    final errors = json['errors'];
    if (errors is List && errors.isNotEmpty) {
      return errors.map((item) {
        if (item is Map) return item['message']?.toString() ?? item.toString();
        return item.toString();
      }).join('; ');
    }
    return json['messages']?.toString() ?? 'unknown error';
  }

  Map<String, dynamic> _asStringKeyedMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return {};
      }
    }
    return {};
  }

  String _shortBody(String body, {int max = 280}) {
    final trimmed = body.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}…';
  }
}

/// True when model output is a tool request rather than a user-facing answer.
bool agentLooksLikeToolCall(String raw) {
  final text = raw.toLowerCase();
  return text.contains('tool_call') ||
      (text.contains('arguments') && RegExp(r'\bname\s*[:=]').hasMatch(text));
}

/// Parses Workers AI tool JSON, including unquoted JS-object style.
Map<String, dynamic>? parseAgentToolCall(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final blobs = <String>[
    ..._toolCallBlobs(text),
    if (agentLooksLikeToolCall(text)) quoteLooseJsonObject(text),
  ];

  for (final blob in blobs) {
    final decoded = _tryDecodeMap(blob) ?? _tryDecodeMap(quoteLooseJsonObject(blob));
    final call = _toolCallFromMap(decoded);
    if (call != null) return call;
  }
  return _toolCallFromLooseText(text);
}

/// Quotes unquoted keys/values so `{tool_call: {name: get_client}}` becomes JSON.
String quoteLooseJsonObject(String raw) {
  var text = raw.trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
    text = text.replaceFirst(RegExp(r'\s*```$'), '');
    text = text.trim();
  }
  text = text.replaceAllMapped(
    RegExp(r'([{\[,]\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:'),
    (match) => '${match[1]}"${match[2]}":',
  );
  text = text.replaceAllMapped(
    RegExp(r':\s*([A-Za-z_][A-Za-z0-9_]*)\s*([,}\]])'),
    (match) {
      final value = match[1]!;
      if (value == 'true' || value == 'false' || value == 'null') {
        return ': $value${match[2]}';
      }
      return ': "$value"${match[2]}';
    },
  );
  return text;
}

List<String> _toolCallBlobs(String raw) {
  var text = raw.trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
    text = text.replaceFirst(RegExp(r'\s*```$'), '');
    text = text.trim();
  }
  final blobs = <String>[];
  void addSpan(int start) {
    if (start < 0) return;
    final end = text.lastIndexOf('}');
    if (end <= start) return;
    blobs.add(text.substring(start, end + 1));
  }

  addSpan(text.indexOf('{"tool_call"'));
  addSpan(text.indexOf('{tool_call'));
  addSpan(text.indexOf('{"name"'));
  if (text.startsWith('{') && text.endsWith('}')) blobs.insert(0, text);
  return [
    for (final blob in blobs)
      if (blob.trim().isNotEmpty) blob,
  ];
}

Map<String, dynamic>? _tryDecodeMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on FormatException {
    return null;
  }
  return null;
}

Map<String, dynamic>? _toolCallFromMap(Map<String, dynamic>? decoded) {
  if (decoded == null) return null;
  var call = decoded['tool_call'];
  if (call is String) {
    call = _tryDecodeMap(call) ?? _tryDecodeMap(quoteLooseJsonObject(call));
  }
  if (call is Map) {
    final name = call['name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    return Map<String, dynamic>.from(call);
  }
  final name = decoded['name']?.toString().trim() ?? '';
  if (name.isNotEmpty && decoded.containsKey('arguments')) {
    return Map<String, dynamic>.from(decoded);
  }
  return null;
}

Map<String, dynamic>? _toolCallFromLooseText(String raw) {
  if (!agentLooksLikeToolCall(raw)) return null;
  final nameMatch = RegExp(
    r'''name\s*[:=]\s*["']?([A-Za-z0-9_]+)["']?''',
  ).firstMatch(raw);
  final name = nameMatch?.group(1)?.trim() ?? '';
  if (name.isEmpty) return null;
  final args = <String, dynamic>{};
  final argsMatch = RegExp(r'arguments\s*[:=]\s*\{([^}]*)\}').firstMatch(raw);
  final inner = argsMatch?.group(1) ?? '';
  for (final pair in inner.split(',')) {
    final parts = pair.split(':');
    if (parts.length < 2) continue;
    final key = parts.first.replaceAll(RegExp(r'''["'\s]'''), '');
    var value = parts.sublist(1).join(':').trim();
    if (value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    if (key.isEmpty) continue;
    args[key] = value;
  }
  return {'name': name, 'arguments': args};
}

/// Strips scripts, styles, and tags from HTML for [web_fetch].
String agentPlainTextFromHtml(String html) {
  var text = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ');
  text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ');
  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length > _fetchMaxChars) {
    return '${text.substring(0, _fetchMaxChars)}…';
  }
  return text;
}
