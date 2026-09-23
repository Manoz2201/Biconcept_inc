import 'package:biconcept/agent/agent_service.dart';
import 'package:biconcept/data/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workersAiRunUri keeps model slashes so Cloudflare can route the model', () {
    final uri = workersAiRunUri(
      accountId: 'abc123',
      model: '@cf/meta/llama-3.2-3b-instruct',
    );

    expect(uri.host, 'api.cloudflare.com');
    expect(
      uri.path,
      '/client/v4/accounts/abc123/ai/run/@cf/meta/llama-3.2-3b-instruct',
    );
    expect(uri.toString(), isNot(contains('%2F')));
  });

  test('agentPlainTextFromHtml strips tags and scripts', () {
    const html = '''
      <html><head><style>p{color:red}</style><script>alert(1)</script></head>
      <body><h1>Gypsum</h1><p>Partition rate &amp; board</p></body></html>
    ''';
    final text = agentPlainTextFromHtml(html);
    expect(text, contains('Gypsum'));
    expect(text, contains('Partition rate & board'));
    expect(text, isNot(contains('alert')));
    expect(text, isNot(contains('<p>')));
  });

  test('parseAgentToolCall accepts unquoted llama-style tool objects', () {
    const raw = '{tool_call: {arguments: {id: 1787085335874}, name: get_client}}';
    final call = parseAgentToolCall(raw);
    expect(call, isNotNull);
    expect(call!['name'], 'get_client');
    final args = call['arguments'];
    expect(args, isA<Map>());
    expect(Map<String, dynamic>.from(args as Map)['id'].toString(), '1787085335874');
    expect(agentLooksLikeToolCall(raw), isTrue);
    expect(parseAgentToolCall('This client is ABC Interiors.'), isNull);
  });

  test('WorkersAiTransport is used instead of a direct Cloudflare URL', () async {
    final agent = AgentService(
      accountId: 'abc123',
      apiToken: 'token',
      transport: (model, payload) async {
        expect(model, kWorkersAiPrimaryModel);
        expect(payload['messages'], isA<List>());
        return const WorkersAiResponse(
          statusCode: 200,
          body: '{"success":true,"result":{"response":"Hello from proxy"}}',
        );
      },
    );
    final reply = await agent.chat('hi');
    expect(reply, 'Hello from proxy');
  });

  test('Cloudflare 401 maps to a credential message', () async {
    final agent = AgentService(
      accountId: 'abc123',
      apiToken: 'token',
      transport: (model, payload) async {
        return const WorkersAiResponse(
          statusCode: 401,
          body: '{"success":false,"errors":[{"code":10000,"message":"Authentication error"}]}',
        );
      },
    );
    final reply = await agent.chat('hi');
    expect(reply, contains('Create a Workers AI API Token'));
    expect(reply, isNot(contains('Fallback:')));
  });

  test('sanitize strips Bearer, quotes, and non-hex account noise', () {
    expect(
      sanitizeCloudflareApiToken('Bearer  abc_token_value  '),
      'abc_token_value',
    );
    expect(sanitizeCloudflareApiToken('"quoted_token"'), 'quoted_token');
    expect(
      sanitizeCloudflareAccountId('  6a86 a3d4-001d 87aa 9809  '),
      '6a86a3d4001d87aa9809',
    );
  });

  test('parseAgentToolCall accepts strict JSON tool calls', () {
    const raw =
        '{"tool_call": {"name": "get_client", "arguments": {"id": "1787085335874"}}}';
    final call = parseAgentToolCall(raw);
    expect(call!['name'], 'get_client');
  });
}
