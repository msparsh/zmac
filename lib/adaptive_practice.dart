import 'dart:math';

enum AdaptiveOperation { addition, subtraction, multiplication, division }

class AdaptiveNumberRange {
  const AdaptiveNumberRange(this.min, this.max);

  final int min;
  final int max;
}

class AdaptiveOperationRanges {
  const AdaptiveOperationRanges({required this.first, required this.second});

  final AdaptiveNumberRange first;
  final AdaptiveNumberRange second;
}

class AdaptiveProblem {
  const AdaptiveProblem({
    required this.operation,
    required this.first,
    required this.second,
    required this.answer,
    this.isExploitationGenerated = false,
  });

  final AdaptiveOperation operation;
  final int first;
  final int second;
  final int answer;
  final bool isExploitationGenerated;

  String get expression => switch (operation) {
    AdaptiveOperation.addition => '$first + $second',
    AdaptiveOperation.subtraction => '$first − $second',
    AdaptiveOperation.multiplication => '$first × $second',
    AdaptiveOperation.division => '$first ÷ $second',
  };
}

class AdaptivePractice {
  AdaptivePractice({
    required Iterable<AdaptiveOperation> operations,
    required Map<AdaptiveOperation, AdaptiveOperationRanges> ranges,
    Random? random,
  }) : operations = List.unmodifiable(operations.toSet()),
       ranges = Map.unmodifiable(ranges),
       _random = random ?? Random() {
    if (this.operations.isEmpty) {
      throw ArgumentError('Adaptive practice needs at least one operation.');
    }
    for (final operation in this.operations) {
      final operationRanges = this.ranges[operation];
      if (operationRanges == null) {
        throw ArgumentError.value(operation, 'ranges', 'Range is required.');
      }
      if (operationRanges.first.min > operationRanges.first.max ||
          operationRanges.second.min > operationRanges.second.max) {
        throw ArgumentError.value(operationRanges, 'ranges', 'Invalid range.');
      }
      if (operation == AdaptiveOperation.division &&
          operationRanges.second.min == 0 &&
          operationRanges.second.max == 0) {
        throw ArgumentError('Division needs a non-zero divisor.');
      }
    }
  }

  static const _baseExplorationRate = 0.25;
  static const _maximumExplorationRate = 0.55;
  static const _recentLimit = 1;

  final List<AdaptiveOperation> operations;
  final Map<AdaptiveOperation, AdaptiveOperationRanges> ranges;
  final Random _random;
  final List<_AdaptiveAttempt> _attempts = [];
  final List<AdaptiveProblem> _recent = [];
  final _generatedFloors = Map<AdaptiveProblem, AdaptiveProblem>.identity();

  AdaptiveProblem nextProblem() {
    if (_attempts.length < operations.length ||
        _random.nextDouble() < _explorationRate()) {
      return _explore();
    }
    final anchors = _slowAttempts();
    if (anchors.isEmpty) return _explore();
    final problem = _problemFromAnchors(anchors);
    if (problem != null) return problem;
    final anchor = _weightedAttempt(anchors);
    return _rememberGenerated(
      _markExploitationGenerated(anchor.problem),
      anchor.difficultyAnchor,
    );
  }

  void record(
    AdaptiveProblem problem, {
    required int elapsedMilliseconds,
    required int incorrectAttempts,
  }) {
    final difficultyAnchor = _generatedFloors.remove(problem) ?? problem;
    _attempts.add(
      _AdaptiveAttempt(
        problem,
        difficultyAnchor,
        max(1, elapsedMilliseconds),
        max(0, incorrectAttempts),
      ),
    );
    _recent.add(problem);
    if (_recent.length > _recentLimit) _recent.removeAt(0);
  }

  AdaptiveProblem _explore() {
    final counts = {
      for (final operation in operations)
        operation: _attempts
            .where((attempt) => attempt.problem.operation == operation)
            .length,
    };
    final fasterOperations = _fasterOperations();
    var explorationOperations = operations
        .where((item) => !fasterOperations.contains(item))
        .toList();
    if (explorationOperations.isEmpty ||
        (fasterOperations.isNotEmpty && _random.nextDouble() < 0.25)) {
      explorationOperations = operations;
    }
    final leastSeen = explorationOperations
        .map((item) => counts[item]!)
        .reduce(min);
    final operation = _pick(
      explorationOperations.where((item) => counts[item] == leastSeen).toList(),
    );
    var anchors = _slowAttempts()
        .where((attempt) => attempt.problem.operation == operation)
        .toList();
    if (anchors.isEmpty) {
      anchors = _attempts
          .where(
            (attempt) =>
                attempt.problem.operation == operation &&
                !attempt.problem.isExploitationGenerated,
          )
          .toList();
    }
    if (anchors.isEmpty) return _randomProblem(operation);

    final anchor = _weightedAttempt(anchors);
    return _exploreFrom(anchor.problem, anchor.difficultyAnchor) ??
        _problemFromAnchors(anchors) ??
        _rememberGenerated(
          _markExploitationGenerated(anchor.problem),
          anchor.difficultyAnchor,
        );
  }

  double _explorationRate() {
    final fasterOperations = _fasterOperations();
    return min(
      _maximumExplorationRate,
      _baseExplorationRate + fasterOperations.length * 0.08,
    ).toDouble();
  }

  Set<AdaptiveOperation> _fasterOperations() {
    final medians = _operationMedians();
    final faster = <AdaptiveOperation>{};
    if (medians.length > 1) {
      final overallMedian = _median(medians.values.toList());
      for (final entry in medians.entries) {
        if (entry.value < overallMedian * 0.75) faster.add(entry.key);
      }
    }
    for (final operation in operations) {
      final attempts = _attempts
          .where((attempt) => attempt.problem.operation == operation)
          .toList();
      if (attempts.length < 6) continue;
      final initialMedian = _median(
        attempts
            .take(attempts.length ~/ 2)
            .map((attempt) => attempt.elapsedMilliseconds)
            .toList(),
      );
      final recentMedian = _median(
        attempts
            .skip(attempts.length - 3)
            .map((attempt) => attempt.elapsedMilliseconds)
            .toList(),
      );
      if (recentMedian < initialMedian * 0.8) faster.add(operation);
    }
    return faster;
  }

  Map<AdaptiveOperation, int> _operationMedians() => {
    for (final operation in operations)
      if (_attempts.any((attempt) => attempt.problem.operation == operation))
        operation: _median(
          _attempts
              .where((attempt) => attempt.problem.operation == operation)
              .toList()
              .reversed
              .take(5)
              .map((attempt) => attempt.elapsedMilliseconds)
              .toList(),
        ),
  };

  int _median(List<int> values) {
    values.sort();
    return values[values.length ~/ 2];
  }

  AdaptiveProblem? _problemFromAnchors(List<_AdaptiveAttempt> anchors) {
    final remaining = List<_AdaptiveAttempt>.of(anchors);
    while (remaining.isNotEmpty) {
      final anchor = _weightedAttempt(remaining);
      remaining.remove(anchor);
      final problem = _similarTo(anchor.problem, anchor.difficultyAnchor);
      if (problem != null) return problem;
    }
    return null;
  }

  List<_AdaptiveAttempt> _slowAttempts() {
    final attempts = <_AdaptiveAttempt>[];
    final fasterOperations = _fasterOperations();
    for (final operation in operations) {
      final operationAttempts = _attempts
          .where(
            (attempt) =>
                attempt.problem.operation == operation &&
                !attempt.problem.isExploitationGenerated,
          )
          .toList();
      if (operationAttempts.isEmpty) continue;

      final responseTimes =
          operationAttempts
              .map((attempt) => attempt.elapsedMilliseconds)
              .toList()
            ..sort();
      final median = responseTimes[responseTimes.length ~/ 2];
      final slowThreshold = max(1000, (median * 0.75).round());
      attempts.addAll(
        operationAttempts.where(
          (attempt) =>
              attempt.incorrectAttempts > 0 ||
              (fasterOperations.contains(operation)
                  ? false
                  : attempt.elapsedMilliseconds >= slowThreshold),
        ),
      );
    }
    if (attempts.isNotEmpty || fasterOperations.isNotEmpty) return attempts;
    return _attempts
        .where((attempt) => !attempt.problem.isExploitationGenerated)
        .toList();
  }

  _AdaptiveAttempt _weightedAttempt(List<_AdaptiveAttempt> attempts) {
    final weights = [
      for (final attempt in attempts)
        max(
          1.0,
          attempt.elapsedMilliseconds /
              1000 *
              (1 + 0.75 * attempt.incorrectAttempts),
        ),
    ];
    final totalWeight = weights.reduce((sum, weight) => sum + weight);
    var choice = _random.nextDouble() * totalWeight;
    for (var index = 0; index < attempts.length; index++) {
      choice -= weights[index];
      if (choice < 0) return attempts[index];
    }
    return attempts.last;
  }

  AdaptiveProblem? _similarTo(
    AdaptiveProblem anchor,
    AdaptiveProblem difficultyAnchor,
  ) {
    final ranges = this.ranges[anchor.operation]!;
    final firstAnchor = _generationFirst(anchor);
    for (var attempt = 0; attempt < 96; attempt++) {
      final first = _pickNearby(firstAnchor, ranges.first);
      final second = _pickNearby(
        anchor.second,
        ranges.second,
        nonZero: anchor.operation == AdaptiveOperation.division,
      );
      final candidate = _makeProblem(anchor.operation, first, second);
      if (_isNoEasier(candidate, difficultyAnchor) &&
          !_isCloseVariant(candidate, anchor) &&
          !_isNearRecent(candidate)) {
        return _rememberGenerated(
          _markExploitationGenerated(candidate),
          difficultyAnchor,
        );
      }
    }
    return _randomAtOrAbove(anchor, difficultyAnchor);
  }

  AdaptiveProblem? _exploreFrom(
    AdaptiveProblem anchor,
    AdaptiveProblem difficultyAnchor,
  ) {
    for (var attempt = 0; attempt < 1024; attempt++) {
      final candidate = _randomProblem(anchor.operation);
      if (_isNoEasier(candidate, difficultyAnchor) &&
          !_isCloseVariant(candidate, anchor) &&
          !_isNearRecent(candidate)) {
        return _rememberGenerated(candidate, difficultyAnchor);
      }
    }
    return null;
  }

  AdaptiveProblem? _randomAtOrAbove(
    AdaptiveProblem anchor,
    AdaptiveProblem difficultyAnchor,
  ) {
    for (var attempt = 0; attempt < 192; attempt++) {
      final candidate = _mutate(anchor);
      if (_isNoEasier(candidate, difficultyAnchor) &&
          !_isNearRecent(candidate)) {
        return _rememberGenerated(
          _markExploitationGenerated(candidate),
          difficultyAnchor,
        );
      }
    }
    for (var attempt = 0; attempt < 192; attempt++) {
      final candidate = _randomProblem(anchor.operation);
      if (_isNoEasier(candidate, difficultyAnchor) &&
          !_isNearRecent(candidate)) {
        return _rememberGenerated(
          _markExploitationGenerated(candidate),
          difficultyAnchor,
        );
      }
    }
    return null;
  }

  AdaptiveProblem _rememberGenerated(
    AdaptiveProblem problem,
    AdaptiveProblem difficultyAnchor,
  ) {
    _generatedFloors[problem] = difficultyAnchor;
    return problem;
  }

  AdaptiveProblem _markExploitationGenerated(AdaptiveProblem problem) =>
      AdaptiveProblem(
        operation: problem.operation,
        first: problem.first,
        second: problem.second,
        answer: problem.answer,
        isExploitationGenerated: true,
      );

  AdaptiveProblem _mutate(AdaptiveProblem anchor) {
    final operationRanges = ranges[anchor.operation]!;
    final first = _pickNearby(_generationFirst(anchor), operationRanges.first);
    final second = _pickNearby(
      anchor.second,
      operationRanges.second,
      nonZero: anchor.operation == AdaptiveOperation.division,
    );
    return _makeProblem(anchor.operation, first, second);
  }

  AdaptiveProblem _randomProblem(AdaptiveOperation operation) {
    final operationRanges = ranges[operation]!;
    final first = _pickFrom(operationRanges.first);
    final second = _pickFrom(
      operationRanges.second,
      nonZero: operation == AdaptiveOperation.division,
    );
    return _makeProblem(operation, first, second);
  }

  AdaptiveProblem _makeProblem(
    AdaptiveOperation operation,
    int first,
    int second,
  ) => switch (operation) {
    AdaptiveOperation.addition => AdaptiveProblem(
      operation: operation,
      first: first,
      second: second,
      answer: first + second,
    ),
    AdaptiveOperation.subtraction => AdaptiveProblem(
      operation: operation,
      first: first + second,
      second: second,
      answer: first,
    ),
    AdaptiveOperation.multiplication => AdaptiveProblem(
      operation: operation,
      first: first,
      second: second,
      answer: first * second,
    ),
    AdaptiveOperation.division => AdaptiveProblem(
      operation: operation,
      first: first * second,
      second: second,
      answer: first,
    ),
  };

  int _generationFirst(AdaptiveProblem problem) => switch (problem.operation) {
    AdaptiveOperation.subtraction ||
    AdaptiveOperation.division => problem.answer,
    AdaptiveOperation.addition ||
    AdaptiveOperation.multiplication => problem.first,
  };

  int _pickNearby(
    int value,
    AdaptiveNumberRange range, {
    bool nonZero = false,
  }) {
    final radius = max(4, (value.abs() * 0.22).round());
    final minimum = max(range.min, value - radius);
    final maximum = min(range.max, value + radius);
    if (minimum > maximum) return _pickFrom(range, nonZero: nonZero);
    return _pickFrom(AdaptiveNumberRange(minimum, maximum), nonZero: nonZero);
  }

  int _pickFrom(AdaptiveNumberRange range, {bool nonZero = false}) {
    if (!nonZero || range.min > 0 || range.max < 0) {
      return range.min + _random.nextInt(range.max - range.min + 1);
    }
    if (range.min == 0 && range.max == 0) {
      throw ArgumentError('Division needs a non-zero divisor.');
    }
    final negativeCount = -range.min;
    final positiveCount = range.max;
    final index = _random.nextInt(negativeCount + positiveCount);
    return index < negativeCount
        ? range.min + index
        : index - negativeCount + 1;
  }

  bool _isNoEasier(AdaptiveProblem candidate, AdaptiveProblem anchor) {
    const similarMagnitudeFloor = 0.75;
    return switch (anchor.operation) {
      AdaptiveOperation.addition =>
        candidate.first.abs() >= anchor.first.abs() * similarMagnitudeFloor &&
            candidate.second.abs() >=
                anchor.second.abs() * similarMagnitudeFloor &&
            candidate.answer.abs() >=
                anchor.answer.abs() * similarMagnitudeFloor &&
            _carryCount(candidate.first, candidate.second) >=
                _carryCount(anchor.first, anchor.second),
      AdaptiveOperation.subtraction =>
        candidate.first.abs() >= anchor.first.abs() * similarMagnitudeFloor &&
            candidate.second.abs() >=
                anchor.second.abs() * similarMagnitudeFloor &&
            candidate.answer.abs() >=
                anchor.answer.abs() * similarMagnitudeFloor &&
            _borrowCount(candidate.first, candidate.second) >=
                _borrowCount(anchor.first, anchor.second),
      AdaptiveOperation.multiplication =>
        candidate.first.abs() >= anchor.first.abs() * similarMagnitudeFloor &&
            candidate.second.abs() >=
                anchor.second.abs() * similarMagnitudeFloor &&
            candidate.answer.abs() >=
                anchor.answer.abs() * similarMagnitudeFloor,
      AdaptiveOperation.division =>
        candidate.first.abs() >= anchor.first.abs() * similarMagnitudeFloor &&
            candidate.second.abs() >=
                anchor.second.abs() * similarMagnitudeFloor &&
            candidate.answer.abs() >=
                anchor.answer.abs() * similarMagnitudeFloor,
    };
  }

  bool _isCloseVariant(AdaptiveProblem candidate, AdaptiveProblem other) {
    if (candidate.operation != other.operation) return false;
    var firstDifference = (candidate.first - other.first).abs();
    var secondDifference = (candidate.second - other.second).abs();
    if (candidate.operation == AdaptiveOperation.addition ||
        candidate.operation == AdaptiveOperation.multiplication) {
      final candidatePair = [candidate.first, candidate.second]..sort();
      final otherPair = [other.first, other.second]..sort();
      firstDifference = (candidatePair[0] - otherPair[0]).abs();
      secondDifference = (candidatePair[1] - otherPair[1]).abs();
    }
    return firstDifference <= 2 && secondDifference <= 2;
  }

  bool _isNearRecent(AdaptiveProblem candidate) =>
      _recent.any((problem) => _isCloseVariant(candidate, problem));

  int _carryCount(int first, int second) {
    var carry = 0;
    var count = 0;
    first = first.abs();
    second = second.abs();
    while (first > 0 || second > 0 || carry > 0) {
      final sum = first % 10 + second % 10 + carry;
      carry = sum ~/ 10;
      if (carry > 0) count++;
      first ~/= 10;
      second ~/= 10;
    }
    return count;
  }

  int _borrowCount(int first, int second) {
    first = first.abs();
    second = second.abs();
    var borrow = 0;
    var count = 0;
    while (first > 0 || second > 0) {
      final top = first % 10 - borrow;
      final bottom = second % 10;
      borrow = top < bottom ? 1 : 0;
      if (borrow > 0) count++;
      first ~/= 10;
      second ~/= 10;
    }
    return count;
  }

  T _pick<T>(List<T> values) => values[_random.nextInt(values.length)];
}

class _AdaptiveAttempt {
  const _AdaptiveAttempt(
    this.problem,
    this.difficultyAnchor,
    this.elapsedMilliseconds,
    this.incorrectAttempts,
  );

  final AdaptiveProblem problem;
  final AdaptiveProblem difficultyAnchor;
  final int elapsedMilliseconds;
  final int incorrectAttempts;
}
