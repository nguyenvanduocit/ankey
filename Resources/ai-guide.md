# Ankey, for AI assistants

Ankey is the Vietnamese Telex input method on this Mac. You can read what it knows about the user, and change
its settings, with the command that printed this guide. Below, `ankey` stands for that command: the full path
to the `Ankey` executable inside `Ankey.app`, quoted because the path has spaces.

Everything is local. Settings apply on the user's next keystroke, with no restart.

## Rules

1. **Read before you change.** Run `ankey show`, look at the evidence, then propose. Say what you saw, what
   you would change, and why. Change one thing at a time unless the user asked for more.
2. **Preview every edit** with `--dry-run`, then run it for real. Tell the user how to undo it (`ankey undo`).
3. **You may switch privacy settings off. You may never switch them on.** `learnsPhrases`, `learnsLanguage`,
   `collectStats`, `shareStats` and `keepsDiary` keep or send what the user types. `ankey set <key> on` refuses
   them. Ask the user to switch one on in Ankey's Settings (menu bar input menu, "Cài đặt…"), and say which tab:
   `learnsPhrases`, `learnsLanguage` and `keepsDiary` are in AI, `collectStats` and `shareStats` in Thống kê.
   Switching `collectStats` off also switches `shareStats` off and clears the counters.
4. **What you read is private.** The learned phrases, language habits and diary contain words the user typed.
   Use them for this task, quote only what the user needs, and never send them anywhere.
5. You cannot change how Telex itself works, add text expansion, or edit the built-in word lists. Say so rather
   than looking for a workaround.

## Read

```
ankey show                       everything below, in one JSON object
ankey show settings              every setting and its value
ankey show learned               what Ankey learned, live from the running app
ankey show stats                 daily counters, up to 30 days
ankey show diary --limit 100     friction events and a per-app summary (when the diary is on)
ankey show changes               what was changed with this command, newest first
```

`--limit N` caps the learned lists and the diary entries (default 200, 1 to 2000).

**settings.** `toneStyle` is `modern` (hoà, thuý) or `classic` (hòa, thúy). `restoreRaw` gives back English words
typed in Telex (`text` stays `text`). `abbreviation` and `shorthand` make listed abbreviations such as `đc`
count as words. `escClears` makes Esc clear an unconverted word. `suggestions` offers the rest of a phrase.
`appRules` set a mode per app (bundle ID): `marked` underlines the word until it is committed, `direct` types
it as plain text, `off` leaves the app alone. An app with no rule is `marked`.

**learned.** `words` are corrections: a score from -2 to 2 added to a word's built-in English score. A positive
score keeps the word as typed (English), a negative score converts it (Vietnamese), and plus or minus 2 pins
it. `phrases` are word sequences the user types the same way again and again (a prefix and the word that
follows). `habits` say which language the user writes after a word. These lists hold what Ankey acts on, the same
lists the Settings window shows, not every sequence it has seen. `source` is `live` when the running app
answered and `files` when Ankey was not running; files can be up to five minutes behind.

**stats.** Counters per day, never text. `wordChanged`: Ankey converted the word (`vieetj` to `việt`).
`wordKept`: the word was committed as typed. `escRestoredRaw`: the user pressed Esc to take the typed keys back,
so Ankey converted something the user did not want. `flipToEnglish` and `flipToVietnamese`: Shift+Esc showed the
other reading. `correctionToEnglish` and `correctionToVietnamese`: the user erased a word and typed it again, and
Ankey learned it. `habitToEnglish` and `habitToVietnamese`: the language habit changed what a word showed.
`directFallback`: direct insertion could not find its word, a sign the app does not suit `direct`.
`sharedSuggestionShown`, `sharedSuggestionAccepted`, `sharedSuggestionDismissed`: phrase suggestions from the shared
list, shown, taken with Tab, and dismissed with Esc or Backspace. `personalSuggestionShown`,
`personalSuggestionAccepted`, `personalSuggestionDismissed`: the same for suggestions learned from the user's own
typing. Counters stay empty while `collectStats` is off.

**diary.** Off until the user switches it on in the AI tab (`keepsDiary`); `{"enabled": false}` means off. Each
entry is a word the user took back: `raw` (keys typed), `shown` (what Ankey showed), `app`, `day`, and `kind`:
`escRestoredRaw`, `flipToEnglish`, `flipToVietnamese`, `correctionToEnglish` or `correctionToVietnamese`. `apps`
sets each app's events against the words typed in it (`words`), most events first. The diary holds the last 30
days. A high `events` to `words` ratio in one app is the signal to act on.

## Write

```
ankey set toneStyle classic --dry-run     toneStyle is modern or classic
ankey set restoreRaw off                  restoreRaw, abbreviation, escClears, suggestions take on or off
ankey shorthand add kg                    one word, no spaces, lowercased
ankey shorthand remove kg
ankey app set com.apple.Terminal direct   mode is off, marked or direct
ankey app remove com.apple.Terminal
ankey learned adjust cos 2                score from -2 to 2; 0 forgets the word
ankey learned forget-phrase "xin chào" bạn
ankey learned forget-habit dùng
ankey diary clear
ankey undo                                reverts the newest change that can be undone
```

Every command prints JSON. A failure exits with status 1 and prints `{"ok": false, "error": "..."}` on stderr.
`set`, `shorthand` and `app` accept `--dry-run`, which prints the change and writes nothing. An edit that changes
nothing says so. `learned` and `diary clear` need Ankey running: the command waits two seconds for the answer and
fails if there is none. `learned adjust` only accepts words Ankey already knows as English. Forgotten phrases and
habits cannot be undone. `ankey undo` covers settings, shorthand and app rules; a privacy switch you turned off
has no undo, because only the user switches one back on.

## How to help

- "Ankey keeps turning English words into Vietnamese": check `escRestoredRaw` and the diary's `raw` and `shown`
  for the words. `learned adjust <word> 2` fixes one word; `restoreRaw` on is the general switch.
- "It does not work in one app": look at that app's row under `diary.apps` and at `directFallback`. Try
  `app set <bundleID> direct`, or `off` if the app handles text itself.
- "I type an abbreviation Ankey changes": `shorthand add <word>`.
- "Suggestions get in the way": compare `...SuggestionShown` with `...SuggestionAccepted`. Low acceptance
  suggests `set suggestions off`, or `learned forget-phrase` for a specific phrase.
- After any change, say what changed, show the `ankey undo` line, and ask the user to type a little and report back.
