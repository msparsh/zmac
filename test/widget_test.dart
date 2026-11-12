import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zmac/main.dart';
import 'package:zmac/session_history.dart';

void main() {
  testWidgets('wrong answers stay put; correct answers advance immediately', (
    tester,
  ) async {
    final storage = _MemoryHistoryStorage();
    final historyStore = SessionHistoryStore(storage: storage);
    await tester.pumpWidget(ZmacApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    expect(find.text('Math practice,\nmade simple.'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('select-adaptive')))
          .selected,
      isTrue,
    );
    await tester.ensureVisible(find.byKey(const Key('select-duration-120')));
    await tester.tap(find.byKey(const Key('select-duration-120')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('start-practice')));
    await tester.tap(find.byKey(const Key('start-practice')));
    await tester.pump();

    final questionCenter = tester
        .getCenter(find.byKey(const Key('problem-expression')))
        .dy;
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(questionCenter, closeTo(screenHeight * 0.29, 5));

    final expression = tester.widget<Text>(
      find.byKey(const Key('problem-expression')),
    );
    final answer = _answerFor(expression.data!);

    await tester.enterText(find.byKey(const Key('answer-input')), '987654321');
    await tester.pump();
    expect(find.text(expression.data!), findsOneWidget);
    expect(find.text('Time: 120s'), findsOneWidget);
    expect(find.text('Score: 0'), findsOneWidget);
    expect(find.text('Addition'), findsNothing);
    expect(find.text('?'), findsNothing);
    expect(find.textContaining('correct answer'), findsNothing);
    expect(find.text('Finish round'), findsNothing);

    await tester.enterText(find.byKey(const Key('answer-input')), '$answer');
    await tester.pump();
    expect(find.text('Score: 1'), findsOneWidget);
    expect(find.byKey(const Key('problem-expression')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('adaptive practice is untimed and exits into session history', (
    tester,
  ) async {
    final historyStore = SessionHistoryStore(storage: _MemoryHistoryStorage());
    await tester.pumpWidget(ZmacApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('select-adaptive')));
    await tester.tap(find.byKey(const Key('select-adaptive')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('start-adaptive')));
    await tester.tap(find.byKey(const Key('start-adaptive')));
    await tester.pump();

    expect(find.byKey(const Key('running-time')), findsNothing);
    expect(find.byKey(const Key('exit-adaptive')), findsOneWidget);
    final adaptiveQuestionCenter = tester
        .getCenter(find.byKey(const Key('problem-expression')))
        .dy;
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(adaptiveQuestionCenter, closeTo(screenHeight * 0.29, 5));

    final expression = tester.widget<Text>(
      find.byKey(const Key('problem-expression')),
    );
    await tester.enterText(
      find.byKey(const Key('answer-input')),
      '${_answerFor(expression.data!)}',
    );
    await tester.pump();
    expect(find.text('Score: 1'), findsOneWidget);

    for (var index = 0; index < 5; index++) {
      final nextExpression = tester.widget<Text>(
        find.byKey(const Key('problem-expression')),
      );
      await tester.enterText(
        find.byKey(const Key('answer-input')),
        '${_answerFor(nextExpression.data!)}',
      );
      await tester.pump();
    }
    final recentTimes = tester.widget<Text>(
      find.byKey(const Key('adaptive-recent-times')),
    );
    final displayedTimes = recentTimes.data!.split(' · ');
    expect(displayedTimes, hasLength(5));
    expect(displayedTimes, everyElement(matches(RegExp(r'^\d+(\.\d)?s$'))));
    final exitX = tester.getCenter(find.byKey(const Key('exit-adaptive'))).dx;
    final timesX = tester
        .getCenter(find.byKey(const Key('adaptive-recent-times')))
        .dx;
    final scoreX = tester.getCenter(find.byKey(const Key('running-score'))).dx;
    expect(exitX, lessThan(timesX));
    expect(timesX, lessThan(scoreX));
    expect(find.text('Score: 6'), findsOneWidget);

    await tester.tap(find.byKey(const Key('exit-adaptive')));
    await tester.pumpAndSettle();
    final sessions = await historyStore.readAll();
    expect(sessions, hasLength(1));
    expect(sessions.single.durationSeconds, 0);
    expect(sessions.single.score, 6);
    expect(sessions.single.problems, hasLength(6));
    await tester.tap(find.byKey(Key('session-score-${sessions.single.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Adaptive ·'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('history lists only date and score and can be cleared', (
    tester,
  ) async {
    final storage = _MemoryHistoryStorage();
    final historyStore = SessionHistoryStore(storage: storage);
    await historyStore.add(_sampleSession());

    await tester.pumpWidget(ZmacApp(historyStore: historyStore));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-history')));
    await tester.pumpAndSettle();

    expect(find.text('Score over time'), findsOneWidget);
    expect(find.byKey(const Key('score-chart')), findsOneWidget);
    expect(find.text('2026-11-12 · 12:00'), findsOneWidget);
    expect(find.byKey(const Key('session-score-run-1')), findsOneWidget);
    expect(find.text('1 problems'), findsNothing);

    await tester.tap(find.byKey(const Key('session-score-run-1')));
    await tester.pumpAndSettle();
    expect(find.text('Session'), findsOneWidget);
    expect(find.text('Score: 1'), findsOneWidget);
    expect(find.byKey(const Key('exploitation-star-1')), findsOneWidget);
    expect(find.text('BEST STREAK'), findsNothing);
    expect(find.text('ACCURACY'), findsNothing);

    await tester.tap(find.text('Back to history'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-clear-history')));
    await tester.pumpAndSettle();

    expect(find.text('No sessions yet.'), findsOneWidget);
    expect(await historyStore.readAll(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
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

SessionHistory _sampleSession() => SessionHistory(
  id: 'run-1',
  startedAt: DateTime(2026, 11, 12, 12),
  durationSeconds: 60,
  elapsedSeconds: 60,
  score: 1,
  incorrectAttempts: 0,
  bestStreak: 1,
  operations: const ['addition'],
  problems: const [
    SessionProblem(
      expression: '5 + 6',
      answer: 11,
      operation: 'addition',
      elapsedMilliseconds: 1200,
      incorrectAttempts: 0,
      isExploitationGenerated: true,
    ),
  ],
);

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
