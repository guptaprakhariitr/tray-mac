# Security Policy

Tray processes your clips, files and notes **entirely on-device**. It does not upload your data, and the shipped build contains no telemetry. Tray never synthesizes paste keystrokes into other apps — clicking a clip only writes it back to the system pasteboard.

## Reporting a vulnerability

Please report security issues privately to the maintainer (open a GitHub security advisory or email the address on the GitHub profile) rather than a public issue. We aim to respond within a few days.

## Notes

- `GoogleService-Info.plist` and any signing keys are never committed (see `.gitignore`).
- Tray runs inside the macOS App Sandbox with only user-selected file access; it does not read other apps' windows or inject input.
