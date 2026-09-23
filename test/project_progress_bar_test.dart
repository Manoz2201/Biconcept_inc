import 'package:biconcept/features/projects/presentation/widgets/project_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ProjectProgressBar shows percentage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProjectProgressBar(progress: 40)),
      ),
    );
    expect(find.text('40%'), findsOneWidget);
  });
}
