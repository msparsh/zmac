import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zmac/main.dart';

void main() {
  testWidgets('wrong answers stay put; a correct answer advances immediately', (
    tester,
  ) async {
    await tester.pumpWidget(const SugarStepApp());
    await tester.ensureVisible(find.byKey(const Key('start-practice')));
    await tester.tap(find.byKey(const Key('start-practice')));
    await tester.pump();

    final expression = tester.widget<Text>(
      find.byKey(const Key('problem-expression')),
    );
    final answer = _answerFor(expression.data!);

    await tester.enterText(find.byKey(const Key('answer-input')), '987654321');
    await tester.pump();
    expect(find.text(expression.data!), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('stat-score'))).data, '0');

    await tester.enterText(find.byKey(const Key('answer-input')), '$answer');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('stat-score'))).data, '1');
    expect(find.byKey(const Key('problem-expression')), findsOneWidget);
  });
}

int _answerFor(String expression) {
  final match = RegExp(
    r'^(-?\d+)\s*([+−×÷])\s*(-?\d+)$',
  ).firstMatch(expression);
  if (match == null) throw StateError('Unexpected problem: $expression');
  final left = int.parse(match.group(1)!);
  final right = int.parse(match.group(3)!);
  return switch (match.group(2)) {
    '+' => left + right,
    '−' => left - right,
    '×' => left * right,
    '÷' => left ~/ right,
    _ => throw StateError('Unexpected operator in $expression'),
  };
}
