-- Stable two-window git diff that follows file/quickfix navigation.
-- Left (base) window shows the git base blob of whatever file the right
-- (work) window holds; the pair re-pins whenever either managed window swaps
-- buffer (e.g. :cnext through a Review quickfix), until toggled off.

local M = {}

local state = {
  group = nil, -- augroup id; nil = inactive
  base_win = nil,
  work_win = nil,
  base = '', -- git rev to diff against; '' = index
  syncing = false, -- reentrancy guard around resync
}

--- Fugitive blob URL for the base version of path, or nil if path is not a
--- tracked-tree file. ('' base = index, i.e. :0:)
local function base_blob(path)
  local rel = vim.fn['fugitive#Path'](path, '')
  if rel == '' then
    return nil
  end
  local obj = (state.base == '' and ':0:' or state.base .. ':') .. rel
  return vim.fn.FugitiveFind(obj)
end

--- Load file into win unless it already shows it (avoids reload churn when
--- navigating hunks within the same file).
local function edit_in(win, file)
  vim.api.nvim_win_call(win, function()
    if vim.api.nvim_buf_get_name(0) == file then
      return
    end
    vim.cmd.edit(vim.fn.fnameescape(file))
  end)
end

local function teardown()
  if state.group then
    vim.api.nvim_del_augroup_by_id(state.group) -- before closing, so WinClosed can't recurse
    state.group = nil
  end
  if state.base_win and vim.api.nvim_win_is_valid(state.base_win) then
    vim.api.nvim_win_close(state.base_win, false)
  end
  vim.cmd('diffoff!')
  state.base_win, state.work_win = nil, nil
end

--- Re-pin the base/work diff around work_win's current file.
local function resync()
  if
    not (
      state.work_win
      and vim.api.nvim_win_is_valid(state.work_win)
      and state.base_win
      and vim.api.nvim_win_is_valid(state.base_win)
    )
  then
    teardown()
    return
  end

  local path = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(state.work_win))
  local blob = base_blob(path)
  if not blob then
    return
  end

  edit_in(state.base_win, blob)
  vim.cmd('diffoff!')
  vim.api.nvim_win_call(state.base_win, vim.cmd.diffthis)
  vim.api.nvim_win_call(state.work_win, vim.cmd.diffthis)
end

--- Toggle the synced diff. base = git rev to diff against ('' = index).
function M.toggle(base)
  if state.group then
    teardown()
    return
  end

  state.base = base or ''
  state.work_win = vim.api.nvim_get_current_win()
  vim.cmd('leftabove vsplit') -- base on the left, work stays on the right
  state.base_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(state.work_win)

  state.group = vim.api.nvim_create_augroup('ReviewDiffSync', { clear = true })

  -- Re-pin when either managed window swaps buffer. resync edits base_win,
  -- which re-fires BufWinEnter; the syncing flag blocks that re-entry.
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = state.group,
    callback = function()
      local cur = vim.api.nvim_get_current_win()
      if (cur == state.work_win or cur == state.base_win) and not state.syncing then
        state.syncing = true
        vim.schedule(function()
          resync()
          state.syncing = false
        end)
      end
    end,
  })

  -- Either window closing ends the session.
  vim.api.nvim_create_autocmd('WinClosed', {
    group = state.group,
    callback = function(ev)
      local win = tonumber(ev.match)
      if win == state.base_win or win == state.work_win then
        teardown()
      end
    end,
  })

  resync()
end

return M
