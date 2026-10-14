# Ankey

![Ankey: Telex Vietnamese input for macOS](.github/social-preview.png)

A Telex Vietnamese input method for macOS. It does one thing: type Vietnamese with Telex, correctly and without getting in the way of English.

- **Telex only.** `aa` gives `â`, `dd` gives `đ`, `s f r x j` set the tone.
- **English stays English.** `smart`, `text` and `hello` come out as typed, because they are not Vietnamese syllables. A word becomes Vietnamese only when it is a syllable that appears in real Vietnamese words, so `does` stays `does` instead of `doé`. Words like `test` and `list` have their own list, and short words like `as` follow the language of the word before them.
- **Text expansion.** Type a shortcut, press space, get the full text.
- **Per-app switch-off.** Pick the apps where Ankey should stay out of the way, such as Terminal.
- **Signed, notarized, self-updating.** Updates come from GitHub Releases and are verified before they replace the installed app.

Requires macOS 13 or later on Apple silicon. The settings window is in Vietnamese.

## Install

Run this in Terminal:

```
curl -fsSL https://raw.githubusercontent.com/nguyenvanduocit/ankey/main/install.sh | sh
```

[`install.sh`](install.sh) downloads the latest release and checks its SHA-256, Developer ID signature and bundle ID before it copies `Ankey.app` to `~/Library/Input Methods/`. Then:

1. Log out and back in. macOS lists a new input method only after that.
2. Open System Settings → Keyboard → Input Sources → Edit… → **+**, choose Vietnamese, then **Ankey**.
3. Switch to Ankey from the input-source menu in the menu bar.

To install by hand, download `Ankey-X.Y.Z.zip` from the [latest release](../../releases/latest), unzip it, move `Ankey.app` to `~/Library/Input Methods/` and continue from step 1.

Later updates install themselves. See [Updates](#updates).

## Typing

| Type | Get | Type | Get |
|---|---|---|---|
| `aa` | â | `s` | sắc (á) |
| `aw` | ă | `f` | huyền (à) |
| `ee` | ê | `r` | hỏi (ả) |
| `oo` | ô | `x` | ngã (ã) |
| `ow` | ơ | `j` | nặng (ạ) |
| `uw` | ư | `z` | remove the tone |
| `dd` | đ | | |

A tone or mark key can come after the whole syllable: `vieetj` gives `việt`, `nguoiwf` gives `người`, and `duwocj` and `duocwj` both give `dược`.

The circumflex key can come late. Type it after the vowels that follow, or after the final: `vayaj` gives `vậy`, `toio` gives `tôi`, `vietej` gives `việt`. A tone key right before it, as in `verse` or `reference`, keeps the letters as typed.

Repeat a key to undo it and keep the literal letters: `aaa` gives `aa`, `noww` gives `now`, `ass` gives `ass`.

**Backspace** removes one typed key. **Esc** gives back the keys you typed when Ankey has added marks (`test` instead of `tét`). On a word without marks, Esc cancels the word, or commits it if you turn that off in Settings.

## Settings

Open them from the Ankey input-source menu → **Cài đặt…** (⌘,). Changes apply on the next key you press.

| Tab | What it does |
|---|---|
| **Chung** | Tone placement: modern (`hoà`, `thuý`) or classic (`hòa`, `thúy`). Keep non-Vietnamese words as typed. Esc cancels or commits the word. |
| **Gõ tắt** | Text expansion, the list of abbreviations that may take marks (`đc` by default), and the list of English words kept as typed. |
| **Ứng dụng** | Per app: Tắt (keys go straight to the app), Gạch chân (the word is underlined while you type) or Trực tiếp (the word is inserted as plain text). |
| **Cập nhật** | Current version, update check, install. |

### Text expansion

Add a shortcut (letters a–z only) and the text it expands to. Type the shortcut and press space, a punctuation key, Return or Tab. The case you typed carries over. With `vn` set to `việt nam`, typing `vn` gives `việt nam`, `Vn` gives `Việt nam` and `VN` gives `VIỆT NAM`. A shortcut wins over Telex, so a shortcut like `dd` expands instead of becoming `đ`.

### Abbreviations

Words such as `đc` are not Vietnamese syllables, so Ankey would leave `ddc` as typed. Words in the abbreviation list still get their marks, so `ddc` gives `đc`. Add your own, such as `đt`.

### English words

Some English words are also valid Vietnamese syllables once Telex adds a tone: `reset` would become `rết`, `test` would become `tét`. Ankey ships two built-in sets of such words, taken from the 20,000 most common English words, so mixed Vietnamese and English text needs no setup.

- **Always English.** Words whose Vietnamese reading is rare, such as `reset`, `boot`, `row`, `saw`, `door`, `test`, `list` and `asap`, come out as typed everywhere.
- **English after English.** Words people also type as Vietnamese, such as `as`, `car`, `last`, `too`, `own` and `chaos` (`cháo`), stay English right after an English word (`git commit as`) and convert after a Vietnamese word or at the start of a sentence (`cảm own` gives `cảm ơn`). Ankey forgets the language at a period, `!`, `?`, Return, Tab and when you switch away.

The **Từ tiếng Anh giữ nguyên** list in Settings adds your own words to the first set. A word glued to code punctuation stays as typed, so `my_var`, `user@host` and `foo.bar(x)` need no escape. Press Esc right after any word to get the keys you typed.

The Vietnamese words that share keys with the first set (`bus` is `bú` but `boot` is not `bôt`) are chosen by frequency in Vietnamese. Words below rank 500 always convert (`cos` is `có`, `nos` is `nó`).

## Updates

Ankey checks GitHub Releases at most once a day. When a new version exists, the input-source menu shows **Cập nhật lên X.Y.Z…**, and Settings → Cập nhật shows the same.

Before replacing the installed app, Ankey checks the SHA-256 of the download against the published checksum, the Developer ID signature of the new app, its bundle ID, and its version against the release tag. The installed app stays untouched until all of those pass.

## Build from source

You need the Xcode command line tools.

```
./build.sh             # run the engine tests, build and sign dist/Ankey.app
./build.sh --install   # also install into ~/Library/Input Methods
```

The build runs the engine tests first and stops when one fails.

Signing uses the first Developer ID Application identity in your keychain. Set `SIGN_IDENTITY=<hash or name>` to pick another one. Without any identity the app is signed ad-hoc, which runs on your own Mac. An ad-hoc build does not self-update.

A fork publishes its own releases by changing `AnkeyReleaseRepo` in `Info.plist` to `owner/name`.

## Thanks

Thanks to **FireGroup** for sponsoring the Apple Developer account that signs and notarizes Ankey. Without it, every release would trigger a Gatekeeper warning on your Mac.
