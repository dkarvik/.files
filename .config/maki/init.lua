require("librarian.init")
require("codex")
require("modes")
require("librarian-git.init")
require("librarian-github.init")
require("librarian-forgejo.init")

maki.setup({
  provider = {
    default_model = "openai/gpt-5.6-terra",
  },
  always_thinking = "xhigh",
})
