import 'package:flutter_test/flutter_test.dart';
import 'package:zmac/session_history.dart';

void main() {
  test('sessions remain available after reopening the history store', () async {
    final storage = _MemoryHistoryStorage();
    final firstStore = SessionHistoryStore(storage: storage);
    final session = SessionHistory(
      id: 'run-1',
      startedAt: DateTime.utc(2026, 11, 12, 12),
      durationSeconds: 120,
      elapsedSeconds: 42,
      score: 2,
      incorrectAttempts: 1,
      bestStreak: 2,
      operations: const ['addition'],
      problems: const [
        SessionProblem(
          expression: '5 + 6',
          answer: 11,
          operation: 'addition',
          elapsedMilliseconds: 1200,
          incorrectAttempts: 1,
          isExploitationGenerated: true,
        ),
        SessionProblem(
          expression: '8 + 4',
          answer: 12,
          operation: 'addition',
          elapsedMilliseconds: 800,
          incorrectAttempts: 0,
        ),
      ],
    );

    await firstStore.add(session);

    final reopenedStore = SessionHistoryStore(storage: storage);
    final loaded = await reopenedStore.readAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'run-1');
    expect(loaded.single.accuracy, closeTo(2 / 3, 0.0001));
    expect(loaded.single.problems[0].elapsedMilliseconds, 1200);
    expect(loaded.single.problems[0].incorrectAttempts, 1);
    expect(loaded.single.problems[0].isExploitationGenerated, isTrue);
  });

  test('invalid stored history is reported instead of discarded', () async {
    final storage = _MemoryHistoryStorage()..value = 'not json';

    await expectLater(
      SessionHistoryStore(storage: storage).readAll(),
      throwsFormatException,
    );
  });

  test('zero-score sessions are not persisted', () async {
    final storage = _MemoryHistoryStorage();
    final store = SessionHistoryStore(storage: storage);

    await store.add(
      SessionHistory(
        id: 'empty-run',
        startedAt: DateTime.utc(2026, 11, 12),
        durationSeconds: 60,
        elapsedSeconds: 60,
        score: 0,
        incorrectAttempts: 4,
        bestStreak: 0,
        operations: const ['addition'],
        problems: const [],
      ),
    );

    expect(storage.value, isNull);
    expect(await store.readAll(), isEmpty);
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
