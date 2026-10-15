-- Pick the maki theme from the terminal background color (OSC 11).
--
-- init.lua runs before maki enters raw mode and starts reading stdin, so a
-- short-lived helper can own the tty: query OSC 11, read the response, and
-- restore termios (TCSAFLUSH) before the TUI claims the terminal. maki never
-- queries OSC 11 itself (ratatui-image runs in from_fontsize mode), so nothing
-- races for the reply.
--
-- jobstart children are setsid'd and get /dev/null stdin, so the helper finds
-- maki's pty by walking /proc/<ancestor>/fd/0. scripts/osc11_bg.py prints
-- "light" or "dark", "skip" when a live TUI already owns the tty in raw mode
-- (a /reload), or exits 1 when the terminal never answered.
--
-- Outcomes: detection wins -> light/dark theme. No answer (tmux without
-- passthrough, headless, non-responding terminal) -> assume light. Skipped
-- (/reload) -> keep maki's current theme.
local M = {}

local LIGHT = "modus_operandi"
local DARK = "modus_vivendi"

-- Last detection, for debugging: { dir, err, skipped }
M.last = nil

local function detect(timeout_ms)
  timeout_ms = timeout_ms or 3000
  local script = maki.fs.joinpath(maki.env.config_dir(), "scripts", "osc11_bg.py")
  local id, err = maki.fn.jobstart({ "python3", script }, { scope = "plugin" })
  if not id then
    return nil, "jobstart: " .. tostring(err), false
  end
  local res, werr = maki.fn.jobwait(id, timeout_ms)
  if type(res) ~= "table" then
    return nil, "jobwait: " .. tostring(werr), false
  end
  local out = res.stdout
  if type(out) == "table" then
    out = table.concat(out, " ")
  end
  out = out and (out:gsub("%s+", ""):lower()) or ""
  if out == "skip" then
    return nil, "live TUI owns the tty (reload?); kept the current theme", true
  end
  if res.exit_code ~= 0 then
    local stderr = res.stderr
    if type(stderr) == "table" then
      stderr = table.concat(stderr, " ")
    end
    return nil, "helper exit " .. tostring(res.exit_code) .. ": " .. tostring(stderr), false
  end
  if out == "light" or out == "dark" then
    return out, nil, false
  end
  return nil, "unparsable helper output: " .. tostring(out), false
end

--- "light" or "dark" for the terminal maki runs in; "light" when the terminal
--- never answered; nil when detection was skipped (reload) so maki keeps its
--- current theme.
function M.direction()
  local dir, err, skipped = detect()
  M.last = { dir = dir, err = err, skipped = skipped }
  if dir then
    return dir
  end
  if not skipped then
    maki.log.warn("osc_theme: " .. tostring(err) .. "; assuming light")
    return "light"
  end
  maki.log.info("osc_theme: " .. tostring(err))
  return nil
end

--- Theme name matching the terminal background, or nil to keep the current
--- selection.
function M.theme()
  local dir = M.direction()
  if not dir then
    return nil
  end
  local theme = dir == "dark" and DARK or LIGHT
  maki.log.info("osc_theme: terminal bg is " .. dir .. ", theme " .. theme)
  return theme
end

return M
