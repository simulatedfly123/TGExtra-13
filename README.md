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


## Disclaimer

This project is an **independent modification (tweak)** for the Telegram app. I am **not affiliated, associated, authorized, endorsed by, or in any way officially connected with Telegram Messenger LLP**, or any of its subsidiaries or affiliates.

This tweak is created solely for **personal and educational purposes**. Use it at your own risk.

**I do not take any responsibility for any issues, damages, or consequences** resulting from the use or misuse of this tweak. If something breaks, it's not my problem.
