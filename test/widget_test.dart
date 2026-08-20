import 'package:biconcept/data/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biconcept/main.dart';

void main() {
  testWidgets('Estimate app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const BiconceptApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('DeepSeek is the default agent API', () {
    expect(SettingsStore.defaultBaseUrl, 'https://api.deepseek.com/v1');
    expect(SettingsStore.defaultModel, 'deepseek-chat');
  });
}
