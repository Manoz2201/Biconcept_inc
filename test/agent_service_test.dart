import 'package:biconcept/agent/agent_service.dart';
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

  test('parseAgentToolCall accepts strict JSON tool calls', () {
    const raw =
        '{"tool_call": {"name": "get_client", "arguments": {"id": "1787085335874"}}}';
    final call = parseAgentToolCall(raw);
    expect(call!['name'], 'get_client');
  });
}
