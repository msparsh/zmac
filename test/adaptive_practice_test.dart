import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zmac/adaptive_practice.dart';

void main() {
  test('exploration gives every selected operation an early turn', () {
    final practice = AdaptivePractice(
      operations: AdaptiveOperation.values,
      ranges: _ranges(),
      random: Random(17),
    );
    final seen = <AdaptiveOperation>{};

    for (var index = 0; index < AdaptiveOperation.values.length; index++) {
      final problem = practice.nextProblem();
      seen.add(problem.operation);
      switch (problem.operation) {
        case AdaptiveOperation.addition:
          expect(problem.answer, problem.first + problem.second);
        case AdaptiveOperation.subtraction:
          expect(problem.answer, problem.first - problem.second);
        case AdaptiveOperation.multiplication:
          expect(problem.answer, problem.first * problem.second);
        case AdaptiveOperation.division:
          expect(problem.second, isNot(0));
          expect(problem.first % problem.second, 0);
          expect(problem.answer, problem.first ~/ problem.second);
      }
      practice.record(problem, elapsedMilliseconds: 1200, incorrectAttempts: 0);
    }

    expect(seen, containsAll(AdaptiveOperation.values));
  });

  test('adaptive practice keeps more than one slow problem in rotation', () {
    final practice = AdaptivePractice(
      operations: const [AdaptiveOperation.addition],
      ranges: _ranges(),
      random: Random(31),
    );
    final slower = AdaptiveProblem(
      operation: AdaptiveOperation.addition,
      first: 70,
      second: 60,
      answer: 130,
    );
    final slowest = AdaptiveProblem(
      operation: AdaptiveOperation.addition,
      first: 95,
      second: 98,
      answer: 193,
    );
    practice
      ..record(slower, elapsedMilliseconds: 9000, incorrectAttempts: 0)
      ..record(slowest, elapsedMilliseconds: 10000, incorrectAttempts: 0);

    var sawSlowerPattern = false;
    var sawSlowestPattern = false;
    for (var index = 0; index < 60; index++) {
      final problem = practice.nextProblem();
      if (problem.first < 90 && problem.second < 90) {
        sawSlowerPattern = true;
      } else if (problem.first >= 95 && problem.second >= 98) {
        sawSlowestPattern = true;
      }
      practice.record(
        problem,
        elapsedMilliseconds: problem.first >= 95 ? 10000 : 9000,
        incorrectAttempts: 0,
      );
    }

    expect(sawSlowerPattern, isTrue);
    expect(sawSlowestPattern, isTrue);
  });

  test('adaptive multiplication varies both factors near a slow anchor', () {
    final practice = AdaptivePractice(
      operations: const [AdaptiveOperation.multiplication],
      ranges: _ranges(),
      random: Random(37),
    );
    const slowProblem = AdaptiveProblem(
      operation: AdaptiveOperation.multiplication,
      first: 12,
      second: 100,
      answer: 1200,
    );
    practice.record(
      slowProblem,
      elapsedMilliseconds: 9000,
      incorrectAttempts: 0,
    );

    final firstFactors = <int>{};
    final secondFactors = <int>{};
    for (var index = 0; index < 20; index++) {
      final problem = practice.nextProblem();
      expect(problem.answer, greaterThanOrEqualTo(900));
      expect(problem.first, greaterThanOrEqualTo(9));
      expect(problem.second, greaterThanOrEqualTo(75));
      firstFactors.add(problem.first);
      secondFactors.add(problem.second);
      practice.record(problem, elapsedMilliseconds: 9000, incorrectAttempts: 0);
    }

    expect(firstFactors.length, greaterThan(1));
    expect(secondFactors.length, greaterThan(3));
  });

  test('exploitation-generated questions are tagged', () {
    final practice = AdaptivePractice(
      operations: const [AdaptiveOperation.addition],
      ranges: _ranges(),
      random: Random(41),
    );
    const slowProblem = AdaptiveProblem(
      operation: AdaptiveOperation.addition,
      first: 95,
      second: 98,
      answer: 193,
    );
    practice.record(
      slowProblem,
      elapsedMilliseconds: 9000,
      incorrectAttempts: 0,
    );

    var taggedCount = 0;
    for (var index = 0; index < 30; index++) {
      final problem = practice.nextProblem();
      if (problem.isExploitationGenerated) taggedCount++;
      practice.record(problem, elapsedMilliseconds: 9000, incorrectAttempts: 0);
    }

    expect(taggedCount, greaterThan(0));
  });

  test('faster operations yield practice to exploration', () {
    final practice = AdaptivePractice(
      operations: const [
        AdaptiveOperation.addition,
        AdaptiveOperation.multiplication,
      ],
      ranges: _ranges(),
      random: Random(43),
    );
    const addition = AdaptiveProblem(
      operation: AdaptiveOperation.addition,
      first: 95,
      second: 98,
      answer: 193,
    );
    const multiplication = AdaptiveProblem(
      operation: AdaptiveOperation.multiplication,
      first: 8,
      second: 9,
      answer: 72,
    );
    for (var index = 0; index < 3; index++) {
      practice
        ..record(addition, elapsedMilliseconds: 4000, incorrectAttempts: 0)
        ..record(
          multiplication,
          elapsedMilliseconds: 4000,
          incorrectAttempts: 0,
        );
    }
    for (var index = 0; index < 3; index++) {
      practice
        ..record(addition, elapsedMilliseconds: 500, incorrectAttempts: 0)
        ..record(
          multiplication,
          elapsedMilliseconds: 4000,
          incorrectAttempts: 0,
        );
    }

    var additionCount = 0;
    var multiplicationCount = 0;
    for (var index = 0; index < 80; index++) {
      final problem = practice.nextProblem();
      if (problem.operation == AdaptiveOperation.addition) {
        additionCount++;
        practice.record(
          problem,
          elapsedMilliseconds: 500,
          incorrectAttempts: 0,
        );
      } else {
        multiplicationCount++;
        practice.record(
          problem,
          elapsedMilliseconds: 4000,
          incorrectAttempts: 0,
        );
      }
    }

    expect(additionCount, lessThan(20));
    expect(multiplicationCount, greaterThan(additionCount));
  });

  test('adaptive variations stay comparable and avoid close number changes', () {
    final practice = AdaptivePractice(
      operations: const [AdaptiveOperation.addition],
      ranges: _ranges(),
      random: Random(23),
    );
    final slowProblem = AdaptiveProblem(
      operation: AdaptiveOperation.addition,
      first: 95,
      second: 98,
      answer: 193,
    );
    practice.record(
      slowProblem,
      elapsedMilliseconds: 9000,
      incorrectAttempts: 1,
    );

    final firstOperands = <int>{};
    final secondOperands = <int>{};
    var previous = slowProblem;
    for (var index = 0; index < 20; index++) {
      final problem = practice.nextProblem();
      expect(problem.operation, AdaptiveOperation.addition);
      expect(
        _carryCount(problem.first, problem.second),
        greaterThanOrEqualTo(2),
      );
      expect(problem.first + problem.second, greaterThanOrEqualTo(145));
      expect(problem.first, greaterThanOrEqualTo(72));
      expect(problem.second, greaterThanOrEqualTo(73));
      firstOperands.add(problem.first);
      secondOperands.add(problem.second);
      expect(
        (problem.first - previous.first).abs() <= 2 &&
            (problem.second - previous.second).abs() <= 2,
        isFalse,
        reason:
            'Consecutive prompts were too close: ${previous.expression}, ${problem.expression} (index $index)',
      );
      practice.record(problem, elapsedMilliseconds: 9000, incorrectAttempts: 0);
      previous = problem;
    }
    expect(firstOperands.length, greaterThan(3));
    expect(secondOperands.length, greaterThan(3));
  });
}

Map<AdaptiveOperation, AdaptiveOperationRanges> _ranges() {
  const addition = AdaptiveOperationRanges(
    first: AdaptiveNumberRange(2, 100),
    second: AdaptiveNumberRange(2, 100),
  );
  const multiplication = AdaptiveOperationRanges(
    first: AdaptiveNumberRange(2, 12),
    second: AdaptiveNumberRange(2, 100),
  );
  return {
    AdaptiveOperation.addition: addition,
    AdaptiveOperation.subtraction: addition,
    AdaptiveOperation.multiplication: multiplication,
    AdaptiveOperation.division: multiplication,
  };
}

int _carryCount(int first, int second) {
  var carry = 0;
  var result = 0;
  while (first > 0 || second > 0 || carry > 0) {
    final sum = first % 10 + second % 10 + carry;
    carry = sum ~/ 10;
    if (carry > 0) result++;
    first ~/= 10;
    second ~/= 10;
  }
  return result;
}
