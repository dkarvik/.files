maki.keymap.set({ "n", "i" }, "<M-e>", function()
  local ok, err = maki.api.run_command("/thinking")
  if not ok then
    maki.ui.flash("could not run /thinking: " .. err)
  end
end, { desc = "Open thinking picker" })
