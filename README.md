# Zmac

A clean, minimal arithmetic practice app built with Flutter.

Choose a mix of addition, subtraction, multiplication, and division; adjust
number ranges; then practice with a timer or in untimed adaptive mode. Correct
answers advance immediately. During timed rounds, only the timer and score are
shown.

Adaptive mode starts by balancing selected operations, then favors questions
that take longer or need more attempts while continuing to explore. The mix
shifts toward exploration as an operation gets faster. It varies the numbers
around multiple slower questions, avoids tiny number changes, and tags
exploitation-generated questions so they do not become new slow-question
anchors. Its learning state resets after each run. Exit adaptive mode at any
time to finish the run.

Completed runs and their per-problem response times, incorrect attempts,
operation breakdowns, streaks, and accuracy are saved locally on this device.
Open **History** from the home screen to review the score graph and any past run. Zmac
does not use accounts, analytics, or network sync.

## Run

```sh
flutter pub get
flutter run -d windows
```

Press `r` in the Flutter terminal to hot reload changes.

## Windows installer

Build the Windows install package with:

```sh
dart run msix:create
```

The MSIX package is written to `dist\Zmac.msix`. It is signed with a local
development certificate for sideloading; Windows may ask to trust that
certificate when installing. Zmac requests no network capabilities.

## Verify

```sh
flutter analyze
flutter test
```
