local M = {}

-- Declare a plugin: {src} is a URL or {src = …, version = …}; {opts} go to
-- vim.pack.add(), which defaults to {confirm = false}.  A checkout listed in
-- g:dev_overrides is used in place instead of cloned.
function M.packadd(src, opts)
  local spec = type(src) == 'table' and src or { src = src }
  local name = spec.name or (spec.src:gsub('%.git$', ''):match('[^/]+$') or '') -- as vim.pack
  local overrides = vim.g.dev_overrides or {}
  local dir = overrides[spec.src] or overrides[name]
  dir = dir and vim.fn.expand(dir)
  if dir and vim.uv.fs_stat(dir) then
    local rtp = vim.opt.rtp:get()
    for _, path in ipairs({ dir, dir .. '/after' }) do
      if vim.uv.fs_stat(path) and not vim.tbl_contains(rtp, path) then
        vim.opt.rtp:append(path)
      end
    end
    if vim.v.vim_did_enter == 1 then
      for _, file in ipairs(vim.fn.glob(dir .. '/{plugin,ftdetect}/**/*.{vim,lua}', false, true)) do
        vim.cmd.source(file)
      end
    end
    return
  end
  return vim.pack.add({ spec }, vim.tbl_extend('force', { confirm = false }, opts or {}))
end

-- Run {callback} after {pattern} is sourced; Vimscript owns the hook, since
-- funcref callbacks cannot cross into Lua.
function M.after_source(pattern, callback)
  vim.fn['init#after_source'](pattern, callback)
end

return M
