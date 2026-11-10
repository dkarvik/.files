local librarian = require("librarian.init")
librarian.register_extension("codex_search")
maki.pack.add({ "https://github.com/dkarvik/maki-codex.git" })
require("modes")
require("thinking")
require("librarian-git.init")
require("librarian-github.init")
require("librarian-forgejo.init")
local osc_theme = require("osc_theme")

maki.setup({
  always_yolo = true,
  always_workflow = true,
  ui = {
    splash_animation = false,
    theme = osc_theme.theme(),
    notifications = "notify",
  },
  provider = {
      excluded_models = { "claude/*-4-*", "claude/*-sonnet-4", "claude/*-opus-5", "claude/*-sonnet-5", "claude/*-1m", "claude/claude-fable-5", "claude/claude-fable-5-1" },
  },
})

maki.pack.add({
  { src = "https://github.com/bzzimmy/maki-claude", version = "main" },
})
