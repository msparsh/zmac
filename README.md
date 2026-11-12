# Zmac

A clean, minimal arithmetic practice app built with Flutter.

Choose a mix of addition, subtraction, multiplication, and division; adjust
number ranges and the round length; then type each answer. Correct answers
advance immediately. During a round, only the timer and score are shown.

Completed runs and their per-problem response times, incorrect attempts,
operation breakdowns, streaks, and accuracy are saved locally on this device.
Open **History** from the home screen to review totals and any past run. Zmac
does not use accounts, analytics, or network sync.

## Run

```sh
flutter pub get
flutter run -d windows
```

Press `r` in the Flutter terminal to hot reload changes.

## Windows installer

Run `powershell -ExecutionPolicy Bypass -File installer\build-installer.ps1`.
The installer is written to `dist\Zmac-Setup.exe`. It installs to the current
user's local programs folder and creates a Start menu shortcut.

## Verify

```sh
flutter analyze
flutter test
```
