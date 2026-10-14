-- Guided walkthrough of a branch diff. A Lua spec of steps becomes a quickfix list; quickfix owns
-- navigation. Whenever a file is shown in a window, every step anchored in it is drawn as virtual
-- lines under its anchor, with a gutter bar along its scope, and everything outside the steps'
-- scopes folded. Steps with no file get a scratch buffer, which may also hold a PNG (vim.ui.img).
--
-- Spec (a Lua file returning):
--   { title = '...', base = '<rev>', steps = { {
--       file = 'src/x.clj', line = 12,  -- work-tree location (quickfix target); omit for a scratch buffer
--       base_line = 9,                  -- set: anchor on the base (removed) side at this line
--       lines = { 20, 45 },             -- optional scope; default: the top-level form around the anchor
--       title = '...', body = [[...]],  -- body: plain text, ``` fences allowed
--       image = 'relative/to/spec.png' } } }

local M = {}

local ns = vim.api.nvim_create_namespace('walkthrough')
local width = 100

local state = {
  group = nil,
  spec = nil,
  dir = nil,
  root = nil,
  imgs = {}, -- scratch buf -> { id, rows, cols, text_rows }
  folds = {}, -- win -> its own {foldmethod, foldenable}, restored when it shows a non-tour buffer
  cell = { w = 9, h = 18 }, -- terminal cell size in px; replaced by the CSI 16t reply
}

--- Ask the terminal for its cell size, so images keep their aspect ratio.
local function query_cell_size()
  vim.api.nvim_create_autocmd('TermResponse', {
    group = state.group,
    callback = function(ev)
      local h, w = ((ev.data and ev.data.sequence) or ''):match('%[6;(%d+);(%d+)t')
      if h then
        state.cell = { w = tonumber(w), h = tonumber(h) }
        return true
      end
    end,
  })
  vim.api.nvim_ui_send('\27[16t')
end

local function png_size(bytes)
  local function u32(i)
    local a, b, c, d = bytes:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

local function hl_defaults()
  vim.api.nvim_set_hl(0, 'WalkthroughTitle', { default = true, link = 'Title' })
  vim.api.nvim_set_hl(0, 'WalkthroughNote', { default = true, link = 'DiagnosticVirtualTextInfo' })
  vim.api.nvim_set_hl(0, 'WalkthroughCode', { default = true, link = 'String' })
  vim.api.nvim_set_hl(0, 'WalkthroughRule', { default = true, link = 'NonText' })
  vim.api.nvim_set_hl(0, 'WalkthroughScope', { default = true, link = 'DiagnosticInfo' })
  vim.api.nvim_set_hl(0, 'WalkthroughScopeNr', { default = true, link = 'DiagnosticInfo' })
end

--- Word-wrap text to width; ``` fences toggle verbatim lines. Returns {{line, is_code}...}.
local function wrap(text)
  local out, in_code = {}, false
  for _, raw in ipairs(vim.split(text, '\n', { plain = true })) do
    if raw:match('^```') then
      in_code = not in_code
    elseif in_code or raw == '' then
      table.insert(out, { raw, in_code })
    else
      local indent = string.rep(' ', vim.fn.strdisplaywidth(raw:match('^(%s*[-%d%.]*%s*)') or ''))
      local line = ''
      for word in raw:gmatch('%S+') do
        if line ~= '' and vim.fn.strdisplaywidth(line .. ' ' .. word) > width then
          table.insert(out, { line, false })
          line = indent .. word
        else
          line = line == '' and word or (line .. ' ' .. word)
        end
      end
      table.insert(out, { line, false })
    end
  end
  return out
end

--- Lines [from, to] a step covers: its `lines`, else the top-level form around `line`
--- (a comment takes the form after it), else just `line`.
local function scope(buf, line, step)
  if step.lines then
    return step.lines[1], step.lines[2]
  end
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not (ok and parser) then
    return line, line
  end
  for node in parser:parse()[1]:root():iter_children() do
    local s, _, e = node:range()
    if s <= line - 1 and line - 1 <= e then
      local next = node:type() == 'comment' and node:next_named_sibling()
      if next then
        e = select(3, next:range())
      end
      return s + 1, e + 1
    end
  end
  return line, line
end

--- The steps drawn in buf, each with its anchor line there.
local function steps_in(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  -- a review_diff base window holds a fugitive blob of the file at the base rev
  local base_path = name:match('^fugitive://') and (vim.fn.FugitiveParse(name)[1] or ''):match(':(.+)$')
  local out = {}
  for i, s in ipairs(state.spec.steps) do
    local line = (s.buf == buf and 1)
      or (base_path and s.base_line and s.file == base_path and s.base_line)
      or (not base_path and not s.base_line and s.file and name == state.root .. '/' .. s.file and s.line)
    if line then
      table.insert(out, { idx = i, step = s, line = math.min(line, vim.api.nvim_buf_line_count(buf)) })
    end
  end
  return out
end

local function note(idx, step, img_rows)
  local vl = { {
    { string.format(' %d/%d  %s ', idx, #state.spec.steps, step.title), 'WalkthroughTitle' },
    { step.buf and '' or step.base_line and '  [removed/base]' or '  [work]', 'WalkthroughRule' },
  } }
  for _, l in ipairs(wrap(vim.trim(step.body or ''))) do
    table.insert(vl, { { '  ' .. l[1], l[2] and 'WalkthroughCode' or 'WalkthroughNote' } })
  end
  local text_rows = #vl
  for _ = 1, img_rows do
    table.insert(vl, { { '' } })
  end
  table.insert(vl, { { string.rep('─', width), 'WalkthroughRule' } })
  return vl, text_rows
end

--- Image size in cells: natural size at most, within the note width and the window height.
local function image_cells(bytes, win, text_rows)
  local iw, ih = png_size(bytes)
  local avail = math.max(vim.api.nvim_win_get_height(win) - text_rows - 3, 1)
  local scale = math.min(1, width * state.cell.w / iw, avail * state.cell.h / ih)
  return math.max(1, math.floor(iw * scale / state.cell.w)), math.max(1, math.ceil(ih * scale / state.cell.h))
end

--- In a diff window the diff owns folding: just open its folds over the scopes.
local function open_scopes(win, scopes)
  vim.api.nvim_win_call(win, function()
    -- ranged fold commands move the cursor
    local view = vim.fn.winsaveview()
    for _, s in ipairs(scopes) do
      vim.cmd(('silent! %d,%dfoldopen!'):format(s[1], s[2]))
    end
    vim.fn.winrestview(view)
  end)
end

--- Fold everything outside the scopes in win, keeping the window's own settings to restore.
local function fold_outside(win, buf, scopes)
  state.folds[win] = state.folds[win] or { foldmethod = vim.wo[win].foldmethod, foldenable = vim.wo[win].foldenable }
  table.sort(scopes, function(a, b) return a[1] < b[1] end)
  vim.api.nvim_win_call(win, function()
    local view = vim.fn.winsaveview()
    vim.wo.foldmethod, vim.wo.foldenable = 'manual', true
    vim.cmd('normal! zE')
    local next = 1
    for _, s in ipairs(scopes) do
      if s[1] > next then
        vim.cmd(('%d,%dfold'):format(next, s[1] - 1))
      end
      next = math.max(next, s[2] + 1)
    end
    if next <= vim.api.nvim_buf_line_count(buf) then
      vim.cmd(('%d,$fold'):format(next))
    end
    vim.fn.winrestview(view)
  end)
end

local function restore_folds(win)
  local f = state.folds[win]
  if f and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_call(win, function()
      vim.wo.foldmethod = 'manual' -- zE only works on manual folds
      vim.cmd('normal! zE')
      vim.wo.foldmethod, vim.wo.foldenable = f.foldmethod, f.foldenable
    end)
  end
  state.folds[win] = nil
end

--- Place or hide a scratch buffer's image in the rows reserved under its note.
local function place_image(buf)
  local im = state.imgs[buf]
  local win = vim.fn.bufwinid(buf)
  if not im then
    return
  end
  local anchor = win ~= -1 and vim.fn.screenpos(win, 1, 1).row or 0
  local top = win ~= -1 and vim.fn.win_screenpos(win)[1] or 0
  local row = anchor + 1 + im.text_rows
  if anchor == 0 or row < top or row + im.rows > top + vim.api.nvim_win_get_height(win) then
    if im.id then
      pcall(vim.ui.img.del, im.id)
      im.id = nil
    end
    return
  end
  local x = vim.fn.win_screenpos(win)[2] + vim.fn.getwininfo(win)[1].textoff + 2
  local opts = { row = row, col = x, width = im.cols, height = im.rows }
  if im.id then
    vim.ui.img.set(im.id, opts)
  else
    opts.zindex = 50
    im.id = vim.ui.img.set(vim.fn.readblob(im.path), opts)
  end
end

--- Draw every step anchored in buf, as shown in win.
local function decorate(win, buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local here = steps_in(buf)
  if #here == 0 then
    restore_folds(win)
    return
  end
  local scopes = {}
  for _, h in ipairs(here) do
    local s = h.step
    local path = s.image and (state.dir .. '/' .. s.image)
    local _, text_rows = note(h.idx, s, 0)
    local cols, rows = 0, 0
    if path then
      cols, rows = image_cells(vim.fn.readblob(path), win, text_rows)
      local old = state.imgs[buf]
      state.imgs[buf] = { id = old and old.id, path = path, cols = cols, rows = rows, text_rows = text_rows }
    end
    vim.api.nvim_buf_set_extmark(buf, ns, h.line - 1, 0, { virt_lines = (note(h.idx, s, rows)), virt_lines_overflow = 'scroll' })
    if not s.buf then
      local from, to = scope(buf, h.line, s)
      table.insert(scopes, { from, to })
      for l = from, to do
        vim.api.nvim_buf_set_extmark(buf, ns, l - 1, 0, {
          sign_text = '▎', sign_hl_group = 'WalkthroughScope', number_hl_group = 'WalkthroughScopeNr', priority = 100,
        })
      end
    end
  end
  if #scopes > 0 and vim.wo[win].diff then
    open_scopes(win, scopes)
  elseif #scopes > 0 and vim.g.walkthrough_fold ~= false then
    fold_outside(win, buf, scopes)
  end
end

--- Show each image whose buffer is on screen, hide the rest.
local function place_images()
  for buf in pairs(state.imgs) do
    place_image(buf)
  end
end

function M.load(path)
  M.close()
  path = vim.fn.fnamemodify(path, ':p')
  hl_defaults()
  state.spec = dofile(path)
  state.dir = vim.fn.fnamemodify(path, ':h')
  state.root = vim.fn.systemlist({ 'git', '-C', state.dir, 'rev-parse', '--show-toplevel' })[1]

  local items = {}
  for i, s in ipairs(state.spec.steps) do
    if s.file then
      items[i] = { filename = state.root .. '/' .. s.file, lnum = s.line or 1, col = 1, text = s.title }
    else
      s.buf = vim.fn.bufnr('walkthrough://' .. s.title)
      if s.buf == -1 then
        s.buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_name(s.buf, 'walkthrough://' .. s.title)
      end
      items[i] = { bufnr = s.buf, lnum = 1, col = 1, text = s.title }
    end
  end
  vim.fn.setqflist({}, ' ', { title = state.spec.title or 'Walkthrough', items = items })

  state.group = vim.api.nvim_create_augroup('Walkthrough', { clear = true })
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = state.group,
    callback = function(ev)
      local win = vim.api.nvim_get_current_win()
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == ev.buf then
          decorate(win, ev.buf)
        end
        place_images()
      end)
    end,
  })
  -- review_diff re-runs diffthis after a file lands, which re-folds; open the scopes again after it
  vim.api.nvim_create_autocmd('DiffUpdated', {
    group = state.group,
    callback = function()
      vim.schedule(function()
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.wo[w].diff then
            decorate(w, vim.api.nvim_win_get_buf(w))
          end
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd({ 'WinScrolled', 'WinClosed' }, {
    group = state.group,
    callback = function() vim.schedule(place_images) end,
  })
  vim.api.nvim_create_autocmd('ColorScheme', { group = state.group, callback = hl_defaults })
  query_cell_size()

  if state.spec.base and vim.fn.exists('*SetGitBase') == 1 then
    vim.fn.SetGitBase(state.spec.base)
  end
  vim.cmd('cfirst')
  local ok, rd = pcall(require, 'review_diff')
  if ok and state.spec.base and vim.g.walkthrough_diff ~= false then
    rd.toggle(state.spec.base)
  end
  -- the first window's BufWinEnter can fire before the group exists
  decorate(vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf())
  vim.schedule(place_images)
end

function M.close()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
  for win in pairs(state.folds) do
    restore_folds(win)
  end
  for _, im in pairs(state.imgs) do
    if im.id then
      pcall(vim.ui.img.del, im.id)
    end
  end
  state.imgs = {}
  if state.group then
    vim.api.nvim_del_augroup_by_id(state.group)
    state.group = nil
  end
end

return M
