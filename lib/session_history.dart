import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _operationNames = {
  'addition',
  'subtraction',
  'multiplication',
  'division',
};

class SessionProblem {
  const SessionProblem({
    required this.expression,
    required this.answer,
    required this.operation,
    required this.elapsedMilliseconds,
    required this.incorrectAttempts,
  });

  final String expression;
  final int answer;
  final String operation;
  final int elapsedMilliseconds;
  final int incorrectAttempts;

  Map<String, Object> toJson() => {
    'expression': expression,
    'answer': answer,
    'operation': operation,
    'elapsedMilliseconds': elapsedMilliseconds,
    'incorrectAttempts': incorrectAttempts,
  };

  factory SessionProblem.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('A saved problem is not an object.');
    }
    final operation = _string(value, 'operation');
    if (!_operationNames.contains(operation)) {
      throw const FormatException('A saved problem has an unknown operation.');
    }
    return SessionProblem(
      expression: _string(value, 'expression'),
      answer: _integer(value, 'answer'),
      operation: operation,
      elapsedMilliseconds: _integer(value, 'elapsedMilliseconds'),
      incorrectAttempts: _integer(value, 'incorrectAttempts'),
    );
  }
}

class SessionHistory {
  const SessionHistory({
    required this.id,
    required this.startedAt,
    required this.durationSeconds,
    required this.elapsedSeconds,
    required this.score,
    required this.incorrectAttempts,
    required this.bestStreak,
    required this.operations,
    required this.problems,
  });

  final String id;
  final DateTime startedAt;
  final int durationSeconds;
  final int elapsedSeconds;
  final int score;
  final int incorrectAttempts;
  final int bestStreak;
  final List<String> operations;
  final List<SessionProblem> problems;

  int get totalResponseMilliseconds =>
      problems.fold(0, (total, problem) => total + problem.elapsedMilliseconds);

  double get averageResponseSeconds =>
      score == 0 ? 0 : totalResponseMilliseconds / 1000 / score;

  double get accuracy {
    final attempts = score + incorrectAttempts;
    return attempts == 0 ? 0 : score / attempts;
  }

  Map<String, Object> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'elapsedSeconds': elapsedSeconds,
    'score': score,
    'incorrectAttempts': incorrectAttempts,
    'bestStreak': bestStreak,
    'operations': operations,
    'problems': problems.map((problem) => problem.toJson()).toList(),
  };

  factory SessionHistory.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('A saved session is not an object.');
    }
    final startedAt = DateTime.tryParse(_string(value, 'startedAt'));
    if (startedAt == null) {
      throw const FormatException('A saved session has an invalid date.');
    }
    final operations = value['operations'];
    final problems = value['problems'];
    if (operations is! List ||
        !operations.every(
          (operation) =>
              operation is String && _operationNames.contains(operation),
        ) ||
        problems is! List) {
      throw const FormatException('A saved session has invalid details.');
    }
    return SessionHistory(
      id: _string(value, 'id'),
      startedAt: startedAt,
      durationSeconds: _integer(value, 'durationSeconds'),
      elapsedSeconds: _integer(value, 'elapsedSeconds'),
      score: _integer(value, 'score'),
      incorrectAttempts: _integer(value, 'incorrectAttempts'),
      bestStreak: _integer(value, 'bestStreak'),
      operations: operations.cast<String>(),
      problems: problems.map(SessionProblem.fromJson).toList(),
    );
  }
}

abstract interface class SessionHistoryStorage {
  Future<String?> read();

  Future<void> write(String value);
}

class SessionHistoryStore {
  SessionHistoryStore({SessionHistoryStorage? storage})
    : _storage = storage ?? _PreferencesSessionHistoryStorage();

  static const _storageKey = 'zmac.session-history.v1';

  final SessionHistoryStorage _storage;

  Future<List<SessionHistory>> readAll() async {
    final contents = await _storage.read();
    if (contents == null) return [];
    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException('Saved session history is not a list.');
    }
    return decoded.map(SessionHistory.fromJson).toList();
  }

  Future<void> add(SessionHistory session) async {
    final sessions = await readAll();
    sessions.insert(0, session);
    await _storage.write(
      jsonEncode(sessions.map((item) => item.toJson()).toList()),
    );
  }
}

class _PreferencesSessionHistoryStorage implements SessionHistoryStorage {
  final _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read() =>
      _preferences.getString(SessionHistoryStore._storageKey);

  @override
  Future<void> write(String value) =>
      _preferences.setString(SessionHistoryStore._storageKey, value);
}

String _string(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field is! String) throw FormatException('Saved field "$key" is invalid.');
  return field;
}

int _integer(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field is! int) throw FormatException('Saved field "$key" is invalid.');
  return field;
}
