---
name: linear-ticket
description: Use when drafting, writing, or filing a Linear ticket/issue, or asked for a Linear title/body/description.
---

# Linear ticket

**Voice:** see the `prose-voice` skill.

## Hard rule: review before create

1. Draft to a temp file (`/tmp/lin-<slug>.md`) using the template below.
2. Open for review via the `remote-edit` skill (blocking open).
3. On return, parse it per the `remote-edit` skill's "Parse a reviewed draft",
   with `${CLAUDE_SKILL_DIR}/aliases.json` and
   `${CLAUDE_SKILL_DIR}/aliases.local.json`. Resolve every `unresolved` entry.
4. Create it via `mcp__linear__save_issue` (no `id`): `fields` as parameters
   verbatim, `title` → `title`, `body` → `description`. `team` is required.

## Default template

```
---
# mcp__linear__save_issue fields — YAML, leave blank to omit. Title = first line below, body = rest.
team:                 # required — name or ID
project:              # name, ID, or slug
assignee:             # user ID, name, email, or "me"
labels:               # name(s), comma-separated
priority:             # none, urgent, high, medium, low
state:                # workflow state type/name/ID
estimate:             # t-shirt size (XS, S, M…) or number
cycle:                # cycle name, number, or ID
milestone:            # name or ID
parentId:             # parent issue ID/identifier (e.g. LIN-123)
dueDate:              # ISO date
---
Title goes on this line

Body prose (Markdown) goes here.
```
