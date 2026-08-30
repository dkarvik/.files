local PROVIDERS = {
  ["openai-codex"] = "openai",
}

local function modes()
  local text, read_err = maki.fs.read("~/.pi/agent/modes.json")
  if not text then
    maki.ui.flash("Could not read ~/.pi/agent/modes.json: " .. read_err)
    return nil
  end

  local config, decode_err = maki.json.decode(text)
  if not config then
    maki.ui.flash("Could not parse modes.json: " .. decode_err)
    return nil
  end

  local names = {}
  for name, mode in pairs(config.modes or {}) do
    if mode.provider and mode.modelId and mode.thinkingLevel then
      names[#names + 1] = name
    end
  end
  table.sort(names)

  if #names == 0 then
    maki.ui.flash("No usable modes in ~/.pi/agent/modes.json")
    return nil
  end

  return config.modes, names, config.currentMode
end

local function mode_name(configured_modes, names, current)
  for _, name in ipairs(names) do
    local mode = configured_modes[name]
    local provider = PROVIDERS[mode.provider] or mode.provider
    local thinking = mode.thinkingLevel
    if current.spec == provider .. "/" .. mode.modelId and current.thinking == thinking then
      return name
    end
  end
end

local function show_mode(name)
  maki.ui.set_status_hint(name and { { " " .. name .. " ", "foreground" } } or nil)
end

local function refresh_mode(current)
  local configured_modes, names = modes()
  if not configured_modes then
    return
  end

  current = current or maki.model.get()
  show_mode(current and mode_name(configured_modes, names, current))
end

maki.keymap.set("n", "<C-Space>", function()
  local configured_modes, names = modes()
  if not configured_modes then
    return
  end

  local current, get_err = maki.model.get()
  if not current then
    maki.ui.flash("Could not get current model: " .. get_err)
    return
  end

  local index = 0
  for i, name in ipairs(names) do
    if mode_name(configured_modes, { name }, current) then
      index = i
      break
    end
  end

  local name = names[index % #names + 1]
  local mode = configured_modes[name]
  local provider = PROVIDERS[mode.provider] or mode.provider
  local thinking = mode.thinkingLevel
  local next_state, set_err = maki.model.set({
    spec = provider .. "/" .. mode.modelId,
    thinking = thinking,
  })
  if not next_state then
    maki.ui.flash("Could not switch mode: " .. set_err)
    return
  end

  show_mode(name)
end, { desc = "Cycle Pi modes" })

maki.api.create_autocmd("SessionFocusChanged", {
  callback = function()
    maki.async.run(refresh_mode)
  end,
})

maki.api.create_autocmd("ModelChanged", {
  callback = function(ev)
    maki.async.run(function()
      refresh_mode(ev.data.model)
    end)
  end,
})
