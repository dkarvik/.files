---
name: remote-edit
description: Hand a file to the user's running editor and block until they finish editing it. Use whenever a draft (PR body, ticket, commit message, any generated file) needs the user's review before you act on it, or when a task says "open this in my editor/vim/nvim".
allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/remote-edit.sh *), Bash(${CLAUDE_SKILL_DIR}/parse-draft.py *)
---

Live servers (address + cwd):

```
!`bash /Users/dominicmonroe/.claude/skills/remote-edit/remote-edit.sh list`
```

## Open a file for review

```
bash ${CLAUDE_SKILL_DIR}/remote-edit.sh <file> [server]
```

Opens `<file>` in a new tab and blocks. Omit `server` when exactly one is live.

## Which server

- One live → use it, don't ask.
- Several → pick the one whose cwd contains the file, or is the repo/worktree the
  task is about. Worktrees are separate servers: `…/repo/worktrees/foo` is not
  `…/repo` — match the exact path the work is in.
- Still ambiguous (same cwd, or file outside every cwd) → ask the user.
- None → tell the user; do not start an nvim.

The list above is a snapshot. If the script exits non-zero mid-session the server
died — re-run `remote-edit.sh list` for a fresh one.

## Waiting

Done = the call **returns**, which happens when the user *closes* the tab
(`:wq`), not when they save — a save leaves the wait live and the user still
editing. It blocks past the foreground timeout into the background; that is
normal, keep waiting for completion. A file-modified notification, or a
killed/stopped/interrupted task status, is **not** the finish. Only re-read the
file once the call genuinely returns.

## Parse a reviewed draft

Drafts with YAML front matter (tickets, PRs) are read back with the parser,
never from memory or a change notice. A change notice shows only edited lines.

```
${CLAUDE_SKILL_DIR}/parse-draft.py <draft> <skill>/aliases.json <skill>/aliases.local.json
```

Each skill has two alias files. `aliases.json` is tracked in yadm: generic
values only (`me`, Linear priorities) plus an empty table for each
workspace-specific field, which makes it strict. `aliases.local.json` is
ignored and holds everything naming the workspace: teams, projects, labels,
states, people. Never write a workspace value into `aliases.json`.

Prints `{"title", "body", "fields", "unresolved"}`: title is the first content
line, body the rest, fields the non-blank front matter with aliases applied.
Use `title`, `body` and `fields` verbatim. A YAML error means the user typed
something YAML can't hold: quote it in the draft and say so.

For each `unresolved` entry:

1. Fetch the live options (labels, projects, users, estimate scale…).
2. Exact case-insensitive match → use it. Otherwise pick the closest fuzzy
   match and state the guess to the user before creating. Ask when no
   candidate is close.
3. Record it in the local file so it resolves next time:
   `${CLAUDE_SKILL_DIR}/parse-draft.py learn <skill>/aliases.local.json <field> '<raw>' '<json value>'`
