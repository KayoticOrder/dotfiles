---
name: japanese-conversation
description: Practice Japanese through free-flowing conversation, calibrated to the user's actual level (comprehensible input / i+1) with gentle inline corrections. Use whenever the user asks to practice Japanese, have a conversation in Japanese, chat/talk in Japanese, roleplay a Japanese scenario, or asks "how's my Japanese been going" / "what am I struggling with". Maintains an encrypted cross-session memory of the user's level, recurring mistakes, and topics covered.
---

# Japanese conversation practice

Comprehensible-input conversation practice (Krashen's i+1: content just
one notch above what the user already knows — understandable with a
little stretch, not a wall of unknown words). Corrects gently and
in-line rather than interrupting the flow, and remembers the user's
level and recurring mistakes across sessions so wording calibration
gets better over time instead of restarting from zero every chat.

The encryption passphrase lives in the user's Bitwarden vault (item name
in `~/.config/japanese-conversation/vault-item`, default `Japanese
Conversation Key`) and is fetched via `rbw` — never written to a local
file, never a standalone value in a tool result. Every command below
that needs it starts with this snippet to resolve the item name, then
pipes straight into gpg's `--passphrase-fd 0`; never capture the
`rbw get` output in a variable you'd print or echo:

```
VAULT_ITEM="$(cat ~/.config/japanese-conversation/vault-item 2>/dev/null || echo 'Japanese Conversation Key')"
```

## Session start

1. Check `rbw unlocked`. If it reports locked (or `rbw` isn't
   installed/configured), tell the user to run `rbw unlock` themselves
   (never ask them to paste their master password into chat) and stop
   until they confirm it's unlocked. If this is genuinely the first time
   (no vault item exists yet either), go to **First-time setup** instead.
2. Decrypt the state file straight to stdout (never write the plaintext
   to a permanent path):
   ```
   rbw get "$VAULT_ITEM" | gpg --batch --yes --pinentry-mode loopback \
     --passphrase-fd 0 --decrypt ~/.claude/skills/japanese-conversation/state.md.gpg
   ```
3. Read it to load: current level estimate, recurring mistakes, recent
   topics, and any stated preferences. Use this to set your opening
   wording level and to naturally pick up threads ("last time you were
   working on casual past tense — want to keep going with that, or
   switch it up?") rather than announcing you read a file.

## First-time setup

1. Confirm `rbw` is installed (`rbw --version`); if not, tell the user
   to install it themselves (`sudo pacman -S rbw` on this machine) since
   it needs sudo. Then confirm they've run `rbw login`/`rbw unlock`
   already (their Bitwarden email + master password + 2FA — all
   themselves, never through chat).
2. Generate a random passphrase into a throwaway file the user reads
   and deletes themselves — the raw value must never appear in a tool
   result or the conversation transcript:
   ```
   openssl rand -base64 32 > /tmp/jp-conv-passphrase.txt && chmod 600 /tmp/jp-conv-passphrase.txt
   ```
   Then tell the user, in these words or similar: "Run `! cat
   /tmp/jp-conv-passphrase.txt` yourself, copy the value into a new
   Secure Note in Bitwarden (suggested item name: `Japanese Conversation
   Key`), then run `! rm /tmp/jp-conv-passphrase.txt` once it's saved."
   Wait for them to confirm before continuing.
3. If they used a different item name than the default, save it:
   ```
   echo "<item name>" > ~/.config/japanese-conversation/vault-item
   ```
4. Run the bootstrap script to get a rough starting-level prior from the
   user's actual known vocabulary (their Anki decks + Migaku export —
   see `bootstrap_level.py`, which reuses the same known-word logic as
   `anki_vocab.py` rather than guessing from scratch):
   ```
   python3 ~/.claude/skills/japanese-conversation/bootstrap_level.py
   ```
   If AnkiConnect isn't reachable (Anki not open) or no Migaku export
   exists, it still runs — just with a smaller/zero known set. Tell the
   user what it found and that this is only a starting point, since raw
   vocab count says nothing about grammar comfort or production vs.
   comprehension gaps — the real signal is how the conversation actually
   goes.
5. Ask the user directly whether the suggested band feels right, and
   whether there's anything specific they want to work on (e.g. "keigo
   makes me freeze", "I can read fine but freeze up speaking casually").
   This is exactly the kind of judgment call to bring to the user rather
   than assume.
6. Write the initial state file (schema below) to a temp file in the
   current scratchpad directory, encrypt it, then delete the plaintext:
   ```
   rbw get "$VAULT_ITEM" | gpg --batch --yes --pinentry-mode loopback \
     --passphrase-fd 0 --symmetric --cipher-algo AES256 \
     -o ~/.claude/skills/japanese-conversation/state.md.gpg <scratchpad-tmp-file>
   rm <scratchpad-tmp-file>
   ```

## During the conversation

- **Wording target (i+1):** default to sentences the user can follow
  with at most a small stretch beyond their recorded level/known
  vocab — not simplified to the point of being boring, not padded with
  words several levels above them. When introducing a genuinely new
  word or grammar point, let context carry most of the meaning rather
  than stopping to translate every time.
- **Corrections — inline gentle recast:** don't call out mistakes
  explicitly or break the flow. Just reply naturally using the
  corrected form, the way a native speaker would in a real
  conversation. If the user explicitly asks ("check my Japanese",
  "was that right?", "explain that"), then give a direct, specific
  correction with a brief reason.
- **Format:** default to free-flowing conversation about whatever the
  user brings up — most natural and immersive. Offer a structured
  roleplay scenario (ordering food, job interview, doctor's visit,
  etc.) when it'd clearly help — e.g. the user seems to want structure,
  mentions an upcoming real situation, or wants to drill something
  specific — rather than defaulting to scripted scenarios.
- Keep a mental note as things come up of: words/grammar that clearly
  gave trouble, words/grammar that landed easily (level may be
  under-calibrated), and topics covered. This becomes the session-end
  update, not something to interrupt the conversation to log.

## Session end

Trigger this when the user signals they're wrapping up (says
bye/thanks/that's it for now, or the conversation naturally trails
off into a new unrelated task) — not after every message.

1. Decrypt the current state file (same command as session start).
2. Update it: adjust the level estimate only if this session gave a
   real signal (consistently breezed through or consistently
   struggled) — don't twitch it on one data point. Add/update recurring
   mistakes (bump a mistake that reappeared rather than duplicating
   it), note today's topics, prune stale entries if the file is getting
   long.
3. Re-encrypt over the temp file, same as first-time setup step 6.
4. Don't run any git commands — the encrypted file now differs on
   disk, but committing/pushing it is the user's call, not yours,
   unless they ask.

## State file schema

Plain markdown, kept short and human-scannable (this is a lightweight
personal log, not a multi-table SRS database):

```markdown
---
last_updated: 2026-08-04
known_vocab_count: 1240
level_estimate: N4
---

## Level notes
Free-text: grammar points solid vs. shaky, comprehension vs.
production gap, anything the user told you directly about where they
are.

## Recurring mistakes
- Confuses は/が in contrastive contexts
- Drops particles even in careful/formal speech (fine when casual)

## Recent topics
- 2026-08-01: ordering food, casual past tense
- 2026-07-28: talking about weekend plans

## Preferences
- Prefers plain/casual form practice over keigo
- Wants explicit corrections only when asked, not by default
```

## Notes

- The passphrase lives only in the user's Bitwarden vault — never in a
  local file, never as a standalone value in a tool result or the
  chat transcript. Always pipe `rbw get` directly into gpg's
  `--passphrase-fd 0` rather than capturing it in a variable you'd
  print or echo. This is what keeps the encrypted state file unreadable
  even though this repo is public on GitHub.
- If `rbw` is locked mid-session, just ask the user to run `rbw unlock`
  themselves and retry — don't work around it by asking for the
  passphrase directly.
- `state.md.gpg` itself lives inside this skill's directory
  (`dots/claude/.claude/skills/japanese-conversation/` in the repo, so
  it syncs across machines via the user's normal dotfiles git workflow
  once they choose to commit it) — but the plaintext must never be
  written outside the scratchpad temp file, and that temp file must
  always be deleted right after encrypting.
- Re-running `bootstrap_level.py` later (e.g. "refresh my baseline")
  is fine and safe any time — it's read-only against Anki/Migaku data,
  it never touches the state file itself.
