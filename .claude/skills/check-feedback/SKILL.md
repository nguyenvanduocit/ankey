---
name: check-feedback
description: Read user feedback and bug reports sent from Ankey (`///bug`, `///feedback`, "Gửi góp ý…") out of Datadog Logs and triage them. Use when the user says "check feedback", "check các feedback", "xem góp ý", "có ai báo bug không", or asks what users reported.
---

# Check Ankey feedback

Reports land in Datadog Logs (site US1, `datadoghq.com`) as service `ankey`, message `ankey.feedback.<trigger>` where trigger is `feedback` or `bug`. Attributes: `feedbackText`, `macOS`, `chip`, `mode`. Source: `App/FeedbackFlow.swift`, `Core/Logs.swift`, `docs/ARCHITECTURE.md` (section Feedback).

The app ships a client token that can only write. Reading goes through `pup`, Datadog's official CLI, signed in over OAuth. No API key or application key is stored anywhere.

## 1. CLI and login

```bash
which pup || brew install pup          # Homebrew core formula "pup" is the Datadog CLI
pup auth status                        # authenticated: true, expires_at in the future
```

Not authenticated or expired without refresh:

```bash
pup auth login --read-only             # opens the browser; the user signs in to Datadog and clicks Authorize
```

The login blocks until the user approves. Run it in the background, tell the user to approve in the browser, and wait for "Login successful". Never type credentials for the user. The token is kept in the macOS keychain and refreshes by itself.

The shell must run in the GUI session: `launchctl managername` prints `Aqua`. Otherwise keychain and browser fail; see the Paseo daemon memory.

## 2. Query

```bash
pup logs search --query 'service:ankey message:ankey.feedback*' --from 90d --limit 200 \
  --no-envelope -o json > /tmp/ankey-feedback.json

jq -r '.data[] | [.attributes.timestamp, .attributes.message, .attributes.attributes.macOS,
  .attributes.attributes.chip, .attributes.attributes.mode, .attributes.attributes.feedbackText] | @tsv' \
  /tmp/ankey-feedback.json
```

Flex storage is unavailable for this account, so `pup` falls back to indexed logs. Indexed retention is about 7-15 days. Report that limit with the result, and compare the earliest report to the date the feedback code shipped (first feedback 2026-10-14).

## 3. Triage

- Table: time, type, text, macOS, chip, mode. Mark test messages ("mẹ này", "tao không biết nữa") as no action.
- For each real report, reproduce before naming a cause. Typing bugs: compile `Core/*.swift` with a throwaway `main.swift` in `/tmp` that feeds keys to `Session` and prints `session.display(Settings())`. Delete the probe afterwards.
- Check the two usual causes of "word stays as typed": the word is missing from `Core/Syllables.swift`, or it is on the English list in `Core/English.swift`.
- Give each finding a confidence label and a `file:line`. Change no code until the user picks a fix.

## 4. Clean up

Remove `/tmp/ankey-feedback.json` once the summary is delivered. It holds users' own words.
