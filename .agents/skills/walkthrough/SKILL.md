---
name: walkthrough
description: Write a guided code walkthrough as a Lua spec for the user's Neovim `:Walkthrough` plugin (~/.config/nvim/lua/walkthrough.lua). Use when asked for a walkthrough, tour or guided read of a branch, diff, PR or design, or to take the user through code in vim.
---

# Neovim walkthrough spec

`:Walkthrough <spec.lua>` turns a spec into a quickfix list, one entry per step. Each step's note is drawn as virtual lines under its anchor line. A gutter bar marks the step's scope and everything outside the scopes is folded. Steps without a file get their own scratch buffer. With `base` set, the plugin's diff view opens: base on the left, work tree on the right.

## File

Write `.qf/<topic>-walkthrough.lua` at the root of the worktree under review, so the plugin can resolve `file` against that repo. Images go in `.qf/<topic>/`. Tell the user: `:Walkthrough .qf/<topic>-walkthrough.lua`.

## Format

The file is Lua that returns one table:

```lua
-- :Walkthrough .qf/<topic>-walkthrough.lua
return {
  title = "<tour title>",                           -- quickfix list title
  base = "<rev>",                                   -- optional: diff base (merge-base sha); enables the diff view
  steps = {
    {                                               -- scratch step: no file
      title = "<step title>",
      image = "<topic>/<name>.png",                 -- optional, relative to the spec file
      body = [[
<note text>
]],
    },
    {
      file = "src/server/handler.ts", line = 191,  -- work-tree path, repo-relative; quickfix target
      title = "<step title>",
      body = [[
Plain text. Wrapped at 100 columns. Indented "-" and "1." lists keep their hanging indent.
```
(verbatim code inside fences, not wrapped)
```
]],
    },
    {
      file = "src/server/router.ts", line = 42,
      base_line = 37,                               -- note anchors on the BASE (removed) side at this line
      lines = { 30, 45 },                           -- optional scope; default is the top-level form around the anchor
      title = "<step title>",
      body = [[...]],
    },
  },
}
```

### Fields

| field | where | meaning |
|---|---|---|
| `title` | spec | quickfix list title |
| `base` | spec | git rev for the diff view. Omit for a tour without a diff. |
| `steps` | spec | ordered list. The order is the tour. |
| `title` | step | required. Shown as `n/N  title` in the note and as the quickfix text. Scratch buffers are named `walkthrough://<title>`, so a scratch step's title must be unique. |
| `body` | step | plain text. ```` ``` ```` lines toggle verbatim blocks. No markdown rendering: `**`, `#` and links show literally. |
| `file` | step | repo-relative work-tree path. Omit it for a scratch step (overview, explainer, summary). |
| `line` | step | 1-based work-tree line. The quickfix entry jumps here. Default 1. |
| `base_line` | step | 1-based line in the file at `base`. The note then appears only in the diff view's base window, tagged `[removed/base]`, so use it for deleted or moved code. Needs `base`. `line` should still point at the work-tree counterpart. |
| `lines` | step | `{from, to}` scope on the side the note is drawn. Default is the treesitter top-level form containing the anchor. A comment takes the form after it. |
| `image` | step | PNG path relative to the spec. Best on scratch steps. |

### Check

Before handing over, load the spec and check every anchor is inside its file:
```sh
nvim --headless -l /dev/stdin <<'EOF'
local spec = dofile('.qf/<topic>-walkthrough.lua')
local root = vim.trim(vim.fn.system('git rev-parse --show-toplevel'))
for i, s in ipairs(spec.steps) do
  if s.file then
    local n = #vim.fn.readfile(root .. '/' .. s.file)
    assert((s.line or 1) <= n, i .. ': line past EOF in ' .. s.file)
  end
end
print(#spec.steps .. ' steps ok')
EOF
```

## Anchors

- `base_line` counts lines in `git show <base>:<file>`, not the work tree.
- Several steps may share one file. Each draws under its own anchor, and the folds keep every step's scope open.
- "Is the walkthrough up to date?" means re-verifying every `line` and `base_line` against the current branch.

## Content

- Order steps for learning, not by file or diff order.
- Put prose that is not about one piece of code (an overview, an explainer, a summary) in a scratch step, not on a random file.
- Say "each step is a quickfix entry". Never name keys such as `]q`. Navigation belongs to the user's own config.

## Images

- PNG only. The plugin scales an image down to fit the 100-column note and the window height, never up.
- Make diagrams wide and short, about 1300×500 px. A tall, narrow image shrinks until its text can't be read. Look at the PNG before handing it over.
