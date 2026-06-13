# Tray — Privacy Policy

_Last updated: 2026_

Tray processes your clips, files and notes **entirely on your Mac**.

- **No data is collected or transmitted.** Clipboard history, shelved files and notes never leave your device.
- **No synthetic paste.** Tray never injects keystrokes into other apps; clicking a clip copies it to the system pasteboard and you press ⌘V yourself.
- **No analytics or tracking** is included in the shipped build.
- **No account** is required.

## Update checks

On launch, Tray makes a single anonymous HTTPS request to a version service (Google Firestore) to check whether a critical update is required. Only the app's version is compared against the latest published version — **no personal data, identifiers or usage data are sent or stored**. If the device is offline or the service is unreachable, the check fails open: Tray starts normally and is never blocked.

If a future version adds optional cloud or analytics features, this policy and the App Store privacy label will be updated, and any such feature will be opt-in.

Questions: open an issue at https://github.com/guptaprakhariitr/tray-mac
