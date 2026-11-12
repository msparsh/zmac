import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zmac/main.dart';
import 'package:zmac/session_history.dart';

void main() {
  testWidgets(
    'wrong answers stay put and correct answers advance immediately',
    (tester) async {
      final storage = _MemoryHistoryStorage();
      final historyStore = SessionHistoryStore(storage: storage);
      await tester.pumpWidget(ZmacApp(historyStore: historyStore));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('start-practice')));
      await tester.tap(find.byKey(const Key('start-practice')));
      await tester.pump();

      final expression = tester.widget<Text>(
        find.byKey(const Key('problem-expression')),
      );
      final answer = _answerFor(expression.data!);

      await tester.enterText(
        find.byKey(const Key('answer-input')),
        '987654321',
      );
      await tester.pump();
      expect(find.text(expression.data!), findsOneWidget);
      expect(find.text('Score 0'), findsOneWidget);
      expect(find.text('ACCURACY'), findsNothing);
      expect(find.text('STREAK'), findsNothing);

      await tester.enterText(find.byKey(const Key('answer-input')), '$answer');
      await tester.pump();
      expect(find.text('Score 1'), findsOneWidget);
      expect(find.byKey(const Key('problem-expression')), findsOneWidget);

      await tester.tap(find.text('Finish round'));
      await tester.pumpAndSettle();
      expect(find.text('Round complete.'), findsOneWidget);
      expect(storage.value, isNotNull);

      await tester.pumpWidget(
        ZmacApp(key: const ValueKey('new-launch'), historyStore: historyStore),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-history')));
      await tester.pumpAndSettle();
      expect(find.text('All sessions'), findsOneWidget);
      expect(find.textContaining('problems'), findsOneWidget);
    },
  );
}

class _MemoryHistoryStorage implements SessionHistoryStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
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
