# Tray — Privacy Policy

_Last updated: 2026_

Tray processes your clips, files and notes **entirely on your Mac**.

- **No data is collected or transmitted.** Clipboard history, shelved files and notes never leave your device.
- **Encrypted at rest.** Clipboard history is stored on your Mac encrypted with AES-GCM; the encryption key is held in the macOS Keychain. macOS may ask you to allow Keychain access the first time — this is expected and protects that key.
- **Optional passcode.** You can set a passcode (private mode) to mask clips until you unlock. It is stored only as a salted PBKDF2 hash, never in plaintext, and cannot be recovered if forgotten.
- **Password-manager safe.** Clipboard items flagged concealed or transient by other apps (e.g. 1Password) are never recorded.
- **No synthetic paste.** Tray never injects keystrokes into other apps; clicking a clip copies it to the system pasteboard and you press ⌘V yourself.
- **No analytics or tracking** is included in the shipped build.
- **No account** is required.

## Update checks

On launch, Tray makes a single anonymous HTTPS request to a version service (Google Firestore) to check whether a critical update is required. Only the app's version is compared against the latest published version — **no personal data, identifiers or usage data are sent or stored**. If the device is offline or the service is unreachable, the check fails open: Tray starts normally and is never blocked.

If a future version adds optional cloud or analytics features, this policy and the App Store privacy label will be updated, and any such feature will be opt-in.

Questions: open an issue at https://github.com/guptaprakhariitr/tray-mac
