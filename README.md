# Ankey

![Ankey: Telex Vietnamese input for macOS](.github/social-preview.png)

Ankey lets you type Vietnamese on your Mac using Telex. It also knows when you are typing English, so words like `smart`, `text` and `hello` stay exactly as you typed them.

- **Type Vietnamese the usual Telex way.** `aa` gives `â`, `dd` gives `đ`, and `s f r x j` add the tone marks.
- **Mix Vietnamese and English freely.** No need to switch back and forth. Ankey only adds marks to words that really exist in Vietnamese.
- **Shortcuts for text you type often.** Type a short code, press space, and the full text appears.
- **Turn it off in certain apps.** For example, you can keep Ankey out of Terminal.
- **Updates itself.** When a new version is out, Ankey tells you and installs it with one click.

Works on Macs with Apple silicon (M1 or newer) running macOS 13 or later. The settings window is in Vietnamese.

## Install

1. Open **Terminal** (press ⌘ Space, type "Terminal", press Return).
2. Copy this line, paste it into Terminal and press Return:

   ```
   curl -fsSL https://raw.githubusercontent.com/nguyenvanduocit/ankey/main/install.sh | sh
   ```

3. **Log out of your Mac and log back in.** macOS only shows a new keyboard after that.
4. Open **System Settings → Keyboard → Input Sources → Edit… → +**, choose **Vietnamese**, then **Ankey**.
5. Click the input-source icon in the menu bar at the top of the screen and pick **Ankey**.

Prefer not to use Terminal? Download the latest `Ankey-X.Y.Z.zip` from the [Releases page](../../releases/latest), unzip it, and drag `Ankey.app` into the folder `~/Library/Input Methods/`. Then continue from step 3.

## How to type

| Type | You get | Type | You get |
|---|---|---|---|
| `aa` | â | `s` | sắc (á) |
| `aw` | ă | `f` | huyền (à) |
| `ee` | ê | `r` | hỏi (ả) |
| `oo` | ô | `x` | ngã (ã) |
| `ow` | ơ | `j` | nặng (ạ) |
| `uw` | ư | `z` | remove the tone |
| `dd` | đ | | |

You can type the tone at the end of the word: `vieetj` gives `việt`, and `nguoiwf` gives `người`.

**Made a mistake?**

- **Backspace** removes the last key you pressed.
- **Esc** brings back the letters you actually typed. If Ankey turned `test` into `tét`, press Esc to get `test` again.
- **Press the same key once more** to cancel a mark: `aaa` gives `aa`, because the third `a` undoes the `â`.

## Settings

Click the Ankey icon in the menu bar and choose **Cài đặt…** (or press ⌘,). Changes take effect on the next key you press.

| Tab | What it is for |
|---|---|
| **Chung** | Where the tone mark goes (`hoà` or `hòa`), and what Esc does. |
| **Gõ tắt** | Your shortcuts, your own abbreviations, and English words you want left alone. |
| **Ứng dụng** | Choose how Ankey behaves in each app, or turn it off for that app. |
| **Cập nhật** | Your current version, and a button to check for updates. |

### Shortcuts

In **Gõ tắt**, add a short code and the text it stands for. Later, type the code and press space (or Return, Tab, or any punctuation) and the full text appears.

For example, if you set `vn` to `việt nam`:

- `vn` gives `việt nam`
- `Vn` gives `Việt nam`
- `VN` gives `VIỆT NAM`

Use letters a–z only for the code.

### Abbreviations

Short forms like `đc` are not real Vietnamese words, so Ankey would normally leave `ddc` alone. Words in the abbreviation list still get their marks, so `ddc` becomes `đc`. `đc` is already there. Add more, such as `đt`.

### English words

A few English words look like Vietnamese words once a tone is added. Without help, `test` would turn into `tét`. Ankey already handles the common ones, so most people never need to change anything:

- Words such as `test`, `list`, `reset` and `boot` always stay English.
- Words such as `as`, `car` and `last` stay English after an English word (`git commit as`) and turn Vietnamese after a Vietnamese word (`cảm own` becomes `cảm ơn`).

If an English word of yours still gets changed, add it to **Từ tiếng Anh giữ nguyên** in Settings. You can also press Esc right after the word to get your letters back.

Code such as `my_var` or `user@host` is left alone automatically.

## Updates

Ankey checks for a new version about once a day. When there is one, the menu shows **Cập nhật lên X.Y.Z…**. Click it to update.

Every update is checked before it replaces your copy of Ankey, so a damaged or tampered download is rejected and your current version keeps working.

## For developers

You need the Xcode command line tools.

```
./build.sh             # run the tests, then build and sign dist/Ankey.app
./build.sh --install   # also install into ~/Library/Input Methods
```

The build stops if a test fails. It signs with the first Developer ID Application identity in your keychain; set `SIGN_IDENTITY=<hash or name>` to use another. Without any identity the app is signed ad-hoc: it runs on your own Mac but does not self-update.

To publish your own releases from a fork, change `AnkeyReleaseRepo` in `Info.plist` to `owner/name`. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/RELEASING.md](docs/RELEASING.md).

## Thanks

Thanks to **FireGroup** for sponsoring the Apple Developer account that signs and notarizes Ankey. Without it, every release would trigger a security warning on your Mac.
