# Ankey

A Telex Vietnamese input method for macOS. It does one thing: type Vietnamese with Telex, correctly and without getting in the way of English.

- **Telex only.** `aa` gives `â`, `dd` gives `đ`, `s f r x j` set the tone.
- **English stays English.** `smart`, `text` and `hello` come out as typed, because they are not Vietnamese syllables. A word becomes Vietnamese only when it is a syllable that appears in real Vietnamese words, so `does` stays `does` instead of `doé`. Words like `test` and `list` have their own list, and short words like `as` follow the language of the word before them.
- **Text expansion.** Type a shortcut, press space, get the full text.
- **Per-app switch-off.** Pick the apps where Ankey should stay out of the way, such as Terminal.
- **Signed, notarized, self-updating.** Updates come from GitHub Releases and are verified before they replace the installed app.

Requires macOS 13 or later on Apple silicon. The settings window is in Vietnamese.

## Install

1. Download `Ankey-X.Y.Z.zip` from the [latest release](../../releases/latest).
2. Unzip it and move `Ankey.app` to `~/Library/Input Methods/`.
3. Log out and back in. macOS lists a new input method only after that.
4. Open System Settings → Keyboard → Input Sources → Edit… → **+**, choose Vietnamese, then **Ankey**.
5. Switch to Ankey from the input-source menu in the menu bar.

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

Repeat a key to undo it and keep the literal letters: `aaa` gives `aa`, `noww` gives `now`, `ass` gives `ass`.

**Backspace** removes one typed key. **Esc** gives back the keys you typed when Ankey has added marks (`test` instead of `tét`). On a word without marks, Esc cancels the word, or commits it if you turn that off in Settings.

## Settings

Open them from the Ankey input-source menu → **Cài đặt…** (⌘,). Changes apply on the next key you press.

| Tab | What it does |
|---|---|
| **Chung** | Tone placement: modern (`hoà`, `thuý`) or classic (`hòa`, `thúy`). Keep non-Vietnamese words as typed. Esc cancels or commits the word. |
| **Gõ tắt** | Text expansion, the list of abbreviations that may take marks (`đc` by default), and the list of English words kept as typed. |
| **Ứng dụng** | Apps where Ankey does not compose. Keys go straight to the app. |
| **Cập nhật** | Current version, update check, install. |

### Text expansion

Add a shortcut (letters a–z only) and the text it expands to. Type the shortcut and press space, a punctuation key, Return or Tab. The case you typed carries over. With `vn` set to `việt nam`, typing `vn` gives `việt nam`, `Vn` gives `Việt nam` and `VN` gives `VIỆT NAM`. A shortcut wins over Telex, so a shortcut like `dd` expands instead of becoming `đ`.

### Abbreviations

Words such as `đc` are not Vietnamese syllables, so Ankey would leave `ddc` as typed. Words in the abbreviation list still get their marks, so `ddc` gives `đc`. Add your own, such as `đt`.

### English words

Some English words are also valid Vietnamese syllables once Telex adds a tone: `test` would become `tét`, `list` would become `lít`. The **Từ tiếng Anh giữ nguyên** list keeps them as typed. It starts with `test`, `best`, `list`, `most`, `is`, `of`, `this`, `there` and similar words, and you can add or remove words.

A second, built-in set covers words people also type as Vietnamese: `as`, `car`, `too`, `own`, `see` and a few more. They stay English right after an English word (`git commit as`) and convert after a Vietnamese word or at the start of a sentence (`cảm own` gives `cảm ơn`). Ankey forgets the language at a period, `!`, `?`, Return, Tab and when you switch away.

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
