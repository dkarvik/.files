require("librarian.init")
require("codex")
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
  }
})
