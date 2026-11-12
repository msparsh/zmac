import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SugarStepApp());
}

const _ink = Color(0xFF40364B);
const _mutedInk = Color(0xFF8A8091);
const _paper = Color(0xFFFFF8F5);
const _coral = Color(0xFFFF796B);
const _pink = Color(0xFFFFE6E5);
const _lavender = Color(0xFFEDE7FF);
const _mint = Color(0xFFE4F5EC);
const _yellow = Color(0xFFFFF1C9);

class SugarStepApp extends StatelessWidget {
  const SugarStepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zmac',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _coral,
          surface: Colors.white,
          onSurface: _ink,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: _ink),
          bodyMedium: TextStyle(color: _ink),
          titleMedium: TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFEAE3E7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFEAE3E7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _coral, width: 1.6),
          ),
        ),
      ),
      home: const PracticePage(),
    );
  }
}

enum _Phase { setup, playing, finished }

enum _Operation { addition, subtraction, multiplication, division }

extension on _Operation {
  String get label => switch (this) {
    _Operation.addition => 'Addition',
    _Operation.subtraction => 'Subtraction',
    _Operation.multiplication => 'Multiplication',
    _Operation.division => 'Division',
  };

  String get symbol => switch (this) {
    _Operation.addition => '+',
    _Operation.subtraction => '−',
    _Operation.multiplication => '×',
    _Operation.division => '÷',
  };

  Color get tint => switch (this) {
    _Operation.addition => _pink,
    _Operation.subtraction => _lavender,
    _Operation.multiplication => _yellow,
    _Operation.division => _mint,
  };
}

class _NumberRange {
  const _NumberRange(this.min, this.max);

  final int min;
  final int max;
}

class _Problem {
  const _Problem({
    required this.expression,
    required this.answer,
    required this.operation,
  });

  final String expression;
  final int answer;
  final _Operation operation;
}

class _ProblemResult {
  const _ProblemResult({
    required this.problem,
    required this.seconds,
    required this.wrongAnswers,
  });

  final _Problem problem;
  final double seconds;
  final int wrongAnswers;
}

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final _random = Random();
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();
  final _rangeControllers = <String, TextEditingController>{
    'addMin': TextEditingController(text: '2'),
    'addMax': TextEditingController(text: '100'),
    'multiplyMin': TextEditingController(text: '2'),
    'multiplyMax': TextEditingController(text: '12'),
    'multiplySecondMin': TextEditingController(text: '2'),
    'multiplySecondMax': TextEditingController(text: '100'),
  };
  final _enabled = <_Operation, bool>{
    for (final operation in _Operation.values) operation: true,
  };
  final _results = <_ProblemResult>[];

  _Phase _phase = _Phase.setup;
  _Problem? _problem;
  _NumberRange _addRange = const _NumberRange(2, 100);
  _NumberRange _multiplyRange = const _NumberRange(2, 12);
  _NumberRange _multiplySecondRange = const _NumberRange(2, 100);
  String? _settingsError;
  int _durationSeconds = 120;
  int _secondsLeft = 120;
  int _score = 0;
  int _totalWrongAnswers = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _currentProblemWrongAnswers = 0;
  int _totalResponseMilliseconds = 0;
  DateTime? _sessionStartedAt;
  DateTime? _problemStartedAt;
  DateTime? _sessionDeadline;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    _answerFocus.dispose();
    for (final controller in _rangeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startSession() {
    final additionMin = int.tryParse(_rangeControllers['addMin']!.text);
    final additionMax = int.tryParse(_rangeControllers['addMax']!.text);
    final multiplicationMin = int.tryParse(
      _rangeControllers['multiplyMin']!.text,
    );
    final multiplicationMax = int.tryParse(
      _rangeControllers['multiplyMax']!.text,
    );
    final secondMin = int.tryParse(
      _rangeControllers['multiplySecondMin']!.text,
    );
    final secondMax = int.tryParse(
      _rangeControllers['multiplySecondMax']!.text,
    );
    final selected = _enabled.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selected.isEmpty) {
      setState(() => _settingsError = 'Pick at least one kind of problem.');
      return;
    }
    if (additionMin == null ||
        additionMax == null ||
        multiplicationMin == null ||
        multiplicationMax == null ||
        secondMin == null ||
        secondMax == null ||
        additionMin > additionMax ||
        multiplicationMin > multiplicationMax ||
        secondMin > secondMax) {
      setState(
        () => _settingsError = 'Check that every number range is valid.',
      );
      return;
    }
    if (selected.contains(_Operation.division) &&
        secondMin == 0 &&
        secondMax == 0) {
      setState(
        () => _settingsError =
            'Division needs a divisor range that includes a non-zero number.',
      );
      return;
    }

    _timer?.cancel();
    _addRange = _NumberRange(additionMin, additionMax);
    _multiplyRange = _NumberRange(multiplicationMin, multiplicationMax);
    _multiplySecondRange = _NumberRange(secondMin, secondMax);
    _results.clear();
    _score = 0;
    _totalWrongAnswers = 0;
    _currentStreak = 0;
    _bestStreak = 0;
    _currentProblemWrongAnswers = 0;
    _totalResponseMilliseconds = 0;
    _secondsLeft = _durationSeconds;
    _sessionStartedAt = DateTime.now();
    _sessionDeadline = _sessionStartedAt!.add(
      Duration(seconds: _durationSeconds),
    );
    _problem = _makeProblem(selected);
    _problemStartedAt = DateTime.now();
    _answerController.clear();
    setState(() {
      _settingsError = null;
      _phase = _Phase.playing;
    });
    _answerFocus.requestFocus();

    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final remaining = _sessionDeadline!.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _finishSession();
      } else {
        final secondsLeft = (remaining.inMilliseconds / 1000).ceil();
        if (secondsLeft != _secondsLeft && mounted) {
          setState(() => _secondsLeft = secondsLeft);
        }
      }
    });
  }

  _Problem _makeProblem(List<_Operation> operations) {
    final operation = operations[_random.nextInt(operations.length)];
    final first = _pick(_rangeFor(operation).$1);
    final secondRange = _rangeFor(operation).$2;
    final second = operation == _Operation.division
        ? _pickNonZero(secondRange)
        : _pick(secondRange);

    return switch (operation) {
      _Operation.addition => _Problem(
        expression: '$first + $second',
        answer: first + second,
        operation: operation,
      ),
      _Operation.subtraction => _Problem(
        expression: '${first + second} − $second',
        answer: first,
        operation: operation,
      ),
      _Operation.multiplication => _Problem(
        expression: '$first × $second',
        answer: first * second,
        operation: operation,
      ),
      _Operation.division => _Problem(
        expression: '${first * second} ÷ $second',
        answer: first,
        operation: operation,
      ),
    };
  }

  (_NumberRange, _NumberRange) _rangeFor(_Operation operation) =>
      switch (operation) {
        _Operation.addition || _Operation.subtraction => (_addRange, _addRange),
        _Operation.multiplication ||
        _Operation.division => (_multiplyRange, _multiplySecondRange),
      };

  int _pick(_NumberRange range) =>
      range.min + _random.nextInt(range.max - range.min + 1);

  int _pickNonZero(_NumberRange range) {
    if (range.max < 0 || range.min > 0) return _pick(range);
    if (range.min == 0) return 1 + _random.nextInt(range.max);
    if (range.max == 0) return range.min + _random.nextInt(-range.min);

    final negativeCount = -range.min;
    final index = _random.nextInt(negativeCount + range.max);
    return index < negativeCount
        ? range.min + index
        : index - negativeCount + 1;
  }

  void _onAnswerChanged(String value) {
    final answer = int.tryParse(value);
    if (_phase == _Phase.playing && answer == _problem?.answer) {
      _solveProblem();
    }
  }

  void _onAnswerSubmitted(String value) {
    final answer = int.tryParse(value);
    if (_phase == _Phase.playing &&
        answer != null &&
        answer != _problem?.answer) {
      setState(() {
        _currentProblemWrongAnswers++;
        _totalWrongAnswers++;
      });
    }
  }

  void _solveProblem() {
    final now = DateTime.now();
    final problem = _problem!;
    final elapsed = now.difference(_problemStartedAt!).inMilliseconds;
    _results.add(
      _ProblemResult(
        problem: problem,
        seconds: elapsed / 1000,
        wrongAnswers: _currentProblemWrongAnswers,
      ),
    );
    _timer?.cancel();

    setState(() {
      _score++;
      _totalResponseMilliseconds += elapsed;
      _currentStreak++;
      _bestStreak = max(_bestStreak, _currentStreak);
      _currentProblemWrongAnswers = 0;
      _problem = _makeProblem(
        _enabled.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList(),
      );
      _problemStartedAt = now;
      _answerController.clear();
    });
    _answerFocus.requestFocus();

    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final remaining = _sessionDeadline!.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _finishSession();
      } else {
        final secondsLeft = (remaining.inMilliseconds / 1000).ceil();
        if (secondsLeft != _secondsLeft && mounted) {
          setState(() => _secondsLeft = secondsLeft);
        }
      }
    });
  }

  void _finishSession() {
    _timer?.cancel();
    if (!mounted || _phase != _Phase.playing) return;
    setState(() {
      _secondsLeft = 0;
      _phase = _Phase.finished;
      _problem = null;
    });
    _answerFocus.unfocus();
  }

  void _returnToSetup() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.setup;
      _settingsError = null;
      _problem = null;
    });
  }

  double get _accuracy {
    final attempts = _score + _totalWrongAnswers;
    return attempts == 0 ? 0 : _score / attempts;
  }

  double get _averageSeconds =>
      _score == 0 ? 0 : _totalResponseMilliseconds / 1000 / _score;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 28, bottom: 42),
                      child: switch (_phase) {
                        _Phase.setup => _buildSetup(),
                        _Phase.playing => _buildGame(),
                        _Phase.finished => _buildResults(),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: _pink,
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
            child: const Icon(Icons.cookie_outlined, color: _coral, size: 23),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'zmac',
                style: TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'a tiny practice break',
                style: TextStyle(color: _mutedInk, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          if (_phase == _Phase.playing)
            _HeaderPill(
              icon: Icons.timer_outlined,
              text: '${_secondsLeft}s',
              tint: _yellow,
            )
          else if (_phase == _Phase.finished)
            _HeaderPill(
              icon: Icons.check_circle_outline,
              text: 'little victory',
              tint: _mint,
            ),
        ],
      ),
    );
  }

  Widget _buildSetup() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A little brain\ncandy.',
              style: TextStyle(
                fontSize: compact ? 38 : 48,
                height: 1.05,
                letterSpacing: -2,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pick your mix. Type the answer. Keep your flow.',
              style: TextStyle(color: _mutedInk, fontSize: 15),
            ),
            const SizedBox(height: 26),
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeading(
                    title: 'Your recipe',
                    subtitle: 'Choose a few things to practice.',
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, gridConstraints) {
                      final cardWidth = gridConstraints.maxWidth >= 630
                          ? (gridConstraints.maxWidth - 12) / 2
                          : gridConstraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final operation in _Operation.values)
                            SizedBox(
                              width: cardWidth,
                              child: _buildOperationCard(operation),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  const _SectionHeading(
                    title: 'Just a little while',
                    subtitle: 'A quick round is plenty.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final seconds in [30, 60, 120, 180, 300])
                        ChoiceChip(
                          label: Text(_durationLabel(seconds)),
                          selected: _durationSeconds == seconds,
                          selectedColor: _pink,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _durationSeconds == seconds
                                ? _coral.withValues(alpha: 0.45)
                                : const Color(0xFFEAE3E7),
                          ),
                          onSelected: (_) =>
                              setState(() => _durationSeconds = seconds),
                        ),
                    ],
                  ),
                  if (_settingsError != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _settingsError!,
                      style: const TextStyle(
                        color: Color(0xFFB63F50),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: compact ? double.infinity : 190,
                    child: FilledButton.icon(
                      key: const Key('start-practice'),
                      onPressed: _startSession,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Start practicing'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'No rush. Just one sweet answer at a time.',
                style: TextStyle(color: _mutedInk, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperationCard(_Operation operation) {
    final selected = _enabled[operation]!;
    final additionFamily =
        operation == _Operation.addition || operation == _Operation.subtraction;
    final rangeKey = additionFamily ? 'add' : 'multiply';
    final firstMinKey = '${rangeKey}Min';
    final firstMaxKey = '${rangeKey}Max';
    final secondMinKey = 'multiplySecondMin';
    final secondMaxKey = 'multiplySecondMax';
    final hasRangeFields =
        operation == _Operation.addition ||
        operation == _Operation.multiplication;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? operation.tint.withValues(alpha: 0.42) : _paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? operation.tint : const Color(0xFFF0E9EC),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: operation.tint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    operation.symbol,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  operation.label,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: Checkbox(
                  key: Key('toggle-${operation.name}'),
                  value: selected,
                  activeColor: _coral,
                  onChanged: (value) =>
                      setState(() => _enabled[operation] = value ?? false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (hasRangeFields)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                const Text(
                  'Range',
                  style: TextStyle(color: _mutedInk, fontSize: 12),
                ),
                _RangeInput(controller: _rangeControllers[firstMinKey]!),
                const Text('to', style: TextStyle(color: _mutedInk)),
                _RangeInput(controller: _rangeControllers[firstMaxKey]!),
                if (!additionFamily) ...[
                  const Text(
                    '×',
                    style: TextStyle(color: _mutedInk, fontSize: 16),
                  ),
                  _RangeInput(controller: _rangeControllers[secondMinKey]!),
                  const Text('to', style: TextStyle(color: _mutedInk)),
                  _RangeInput(controller: _rangeControllers[secondMaxKey]!),
                ],
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 39),
              child: Text(
                additionFamily
                    ? 'Addition, in reverse.'
                    : 'Multiplication, in reverse.',
                style: const TextStyle(color: _mutedInk, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _durationLabel(int seconds) => switch (seconds) {
    30 => '30 sec',
    60 => '1 min',
    120 => '2 min',
    180 => '3 min',
    _ => '5 min',
  };

  Widget _buildGame() {
    final currentProblem = _problem!;
    final progress = _secondsLeft / _durationSeconds;
    return Column(
      children: [
        _Surface(
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Your little sprint',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_secondsLeft sec left',
                    style: TextStyle(
                      color: _secondsLeft <= 10 ? _coral : _mutedInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: _pink,
                  color: _coral,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  _LiveStat(label: 'SCORE', value: '$_score', tint: _pink),
                  _LiveStat(
                    label: 'STREAK',
                    value: '$_currentStreak',
                    tint: _yellow,
                  ),
                  _LiveStat(
                    label: 'ACCURACY',
                    value: '${(_accuracy * 100).round()}%',
                    tint: _mint,
                  ),
                  _LiveStat(
                    label: 'AVG / Q',
                    value: _score == 0
                        ? '—'
                        : '${_averageSeconds.toStringAsFixed(1)}s',
                    tint: _lavender,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Surface(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 18),
            child: Column(
              children: [
                Text(
                  currentProblem.operation.label.toLowerCase(),
                  style: const TextStyle(
                    color: _mutedInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 15),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    Text(
                      currentProblem.expression,
                      key: const Key('problem-expression'),
                      style: TextStyle(
                        color: _ink,
                        fontSize: MediaQuery.sizeOf(context).width < 500
                            ? 34
                            : 46,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const Text(
                      '=',
                      style: TextStyle(
                        color: _mutedInk,
                        fontSize: 38,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(
                      width: 132,
                      child: TextField(
                        key: const Key('answer-input'),
                        controller: _answerController,
                        focusNode: _answerFocus,
                        autofocus: false,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                        ),
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                        ],
                        decoration: const InputDecoration(
                          hintText: '?',
                          hintStyle: TextStyle(color: Color(0xFFC9C0CA)),
                        ),
                        onChanged: _onAnswerChanged,
                        onSubmitted: _onAnswerSubmitted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 21),
                const Text(
                  'A right answer takes you straight to the next one.',
                  style: TextStyle(color: _mutedInk, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: _returnToSetup,
          icon: const Icon(Icons.tune_rounded, size: 16),
          label: const Text('End round'),
          style: TextButton.styleFrom(foregroundColor: _mutedInk),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final elapsedSeconds = _durationSeconds - _secondsLeft;
    final operationSummaries = <_Operation, List<_ProblemResult>>{
      for (final operation in _Operation.values)
        operation: _results
            .where((result) => result.problem.operation == operation)
            .toList(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sweet little\nrun.',
          style: TextStyle(
            color: _ink,
            fontSize: 46,
            height: 1.05,
            letterSpacing: -2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Every answer counts. Here’s how it went.',
          style: TextStyle(color: _mutedInk, fontSize: 14),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 420 ? 2 : 3;
            final tileWidth =
                (constraints.maxWidth - (columns - 1) * 10) / columns;
            final stats = [
              ('SCORE', '$_score', _pink),
              ('ACCURACY', '${(_accuracy * 100).round()}%', _mint),
              ('BEST STREAK', '$_bestStreak', _yellow),
              (
                'AVG / ANSWER',
                '${_averageSeconds.toStringAsFixed(1)}s',
                _lavender,
              ),
              ('TIME PLAYED', _formatTime(elapsedSeconds), _yellow),
              ('MISSES', '$_totalWrongAnswers', _pink),
            ];
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (label, value, tint) in stats)
                  SizedBox(
                    width: tileWidth,
                    child: _ResultStat(label: label, value: value, tint: tint),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                title: 'Your mix',
                subtitle: 'A closer look at each flavor.',
              ),
              const SizedBox(height: 10),
              for (final operation in _Operation.values)
                if (operationSummaries[operation]!.isNotEmpty)
                  _OperationResultRow(
                    operation: operation,
                    results: operationSummaries[operation]!,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading(
                title: 'Problem trail',
                subtitle:
                    '$_score answered · $_totalWrongAnswers misses · each time is per question.',
              ),
              if (_results.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    'No answers this time. Ready for another go?',
                    style: TextStyle(color: _mutedInk, fontSize: 13),
                  ),
                )
              else ...[
                const SizedBox(height: 11),
                for (var index = 0; index < _results.length; index++)
                  _ProblemTrailRow(index: index + 1, result: _results[index]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _returnToSetup,
          icon: const Icon(Icons.replay_rounded, size: 18),
          label: const Text('Make another little mix'),
          style: FilledButton.styleFrom(
            backgroundColor: _coral,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return minutes == 0 ? '${remainder}s' : '${minutes}m ${remainder}s';
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF2EBEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C493746),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: _mutedInk, fontSize: 12)),
      ],
    );
  }
}

class _RangeInput extends StatelessWidget {
  const _RangeInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 34,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,6}')),
        ],
        style: const TextStyle(color: _ink, fontSize: 12),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.text,
    required this.tint,
  });

  final IconData icon;
  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _ink),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _mutedInk,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            key: Key('stat-${label.toLowerCase().replaceAll(' ', '-')}'),
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _mutedInk,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationResultRow extends StatelessWidget {
  const _OperationResultRow({required this.operation, required this.results});

  final _Operation operation;
  final List<_ProblemResult> results;

  @override
  Widget build(BuildContext context) {
    final average =
        results.map((result) => result.seconds).reduce((a, b) => a + b) /
        results.length;
    final misses = results.fold<int>(
      0,
      (total, result) => total + result.wrongAnswers,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: operation.tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                operation.symbol,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              operation.label,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '${results.length} solved',
            style: const TextStyle(color: _mutedInk, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Text(
            '${average.toStringAsFixed(1)}s avg',
            style: const TextStyle(color: _mutedInk, fontSize: 12),
          ),
          if (misses > 0) ...[
            const SizedBox(width: 12),
            Text(
              '$misses miss${misses == 1 ? '' : 'es'}',
              style: const TextStyle(color: _mutedInk, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProblemTrailRow extends StatelessWidget {
  const _ProblemTrailRow({required this.index, required this.result});

  final int index;
  final _ProblemResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '#$index',
              style: const TextStyle(color: _mutedInk, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              '${result.problem.expression} = ${result.problem.answer}',
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${result.seconds.toStringAsFixed(1)}s',
            style: const TextStyle(color: _mutedInk, fontSize: 12),
          ),
          if (result.wrongAnswers > 0) ...[
            const SizedBox(width: 10),
            Text(
              '${result.wrongAnswers} miss${result.wrongAnswers == 1 ? '' : 'es'}',
              style: const TextStyle(color: _mutedInk, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
