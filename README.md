# TGExtra
A simple Telegram iOS Tweak.

To Open Tweak menu : Longpress screen with 3 finger (if no flex injected) of 4 fingers.

## Screenshots

![Screenshot 1](Screenshots/1.png)
![Screenshot 2](Screenshots/2.png)

## Features

- Disable Ads
- Ghost Mode
- No Read Receipt for messages and Stories
- Allow saving Protected Content (the bundled TL schema must match the client: this build ships the layer 230 schema from Telegram 13.0, so use it with Telegram 13.0)

## Telegram 13.0 port

- Bundled TL schema updated from Telegram-iOS `release-13.0.0` (layer 230); the protected-content patches were re-applied to `message`, `channel`, `chat` and `user`, and extended to `userFull` (protected private chats) and `storyItem`.
- `messages.getSponsoredMessages` constructor updated to `0x3d6ce850`.
- The "Disable Ads" switch no longer shares its settings key with "Disable Online Status".
- `.github/workflows/ipa.yml` builds the tweak and injects it into a decrypted IPA in one run (URL input, or the `.ipa` asset of an `ipa-source` release).
- `.github/workflows/telegram.yml` builds Telegram itself from the official sources (`release-13.0.0`, Xcode 26.6, the same fake-codesigning setup as Telegram's own CI) and then runs `ipa.yml` on the result, so no third-party decrypted IPA is needed.


## Disclaimer

This project is an **independent modification (tweak)** for the Telegram app. I am **not affiliated, associated, authorized, endorsed by, or in any way officially connected with Telegram Messenger LLP**, or any of its subsidiaries or affiliates.

This tweak is created solely for **personal and educational purposes**. Use it at your own risk.

**I do not take any responsibility for any issues, damages, or consequences** resulting from the use or misuse of this tweak. If something breaks, it's not my problem.

## Logging in on a re-signed build

Two additions for accounts that never receive a login code:

- **SMS Login Code** (Misc section, on by default) strips `allow_firebase` and the APNs token from `auth.sendCode`. With them set the server may answer `sentCodeTypeFirebaseSms`, which expects the client to receive a silent push carrying a secret and return it through `auth.requestFirebaseSms` before any code is sent - a re-signed build never gets that push, so no code is sent at all. Without them the client reports what it can actually do and the server falls back to a plain SMS, exactly as the app itself does when iOS gives it no push token.
- A **QR login** button on the phone number screen calls the app's own `debugQrTap:`, which exports a login token and draws the code (the same mechanism the desktop client uses). Scan it from a device where the account is already open: Settings -> Devices -> Link Device. A long press on the button opens the app's debug menu, where logging is turned on.

## Fast tweak updates

Rebuilding Telegram takes ~1.5 hours, but the injected IPA already loads `@rpath/TGExtra.dylib`, so a tweak change only needs the new dylib swapped in:

1. Change the tweak sources, commit and push.
2. `python tools/quick_update.py --ipa build/ph.telegra.Telegraph-13.0-TGExtra-1.3.0.ipa` builds the tweak with `tweak.yml` (~5-7 minutes), downloads the `.deb` and writes `...-updated-<time>.ipa` next to the input.
3. Sign and install it as usual.

`tools/update_ipa.py --ipa <ipa> --deb <deb> -o <out>` does only the local swap (arm64 slice of `TGExtra.dylib` + `TGExtra.bundle`). Changes to Telegram itself still need `telegram.yml`.
