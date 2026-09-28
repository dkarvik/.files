-- fzf-lua: the plugin's own script defers :FzfLua. Setup runs on first use via
-- a wrapper command registered once plugin/fzf-lua.lua has been sourced.

local init = require('init')

init.after_source('*/plugin/fzf-lua.lua', function()
  local configured = false

  vim.api.nvim_create_user_command('FzfLua', function(opts)
    if not configured then
      require('fzf-lua').setup({
        'ivy',
        files = { follow = true },
        buffers = {
          actions = {
            ['ctrl-x'] = function(selected, opts)
              local path = require('fzf-lua.path')
              for _, s in ipairs(selected) do
                local entry = path.entry_to_file(s, opts)
                if entry.bufnr then
                  vim.cmd.Bdelete(entry.bufnr)
                end
              end
              require('fzf-lua').resume()
            end,
          },
        },
      })
      configured = true
    end
    require('fzf-lua.cmd').run_command(unpack(opts.fargs))
  end, { nargs = '*', bang = true, range = true })
end)

init.packadd('https://github.com/nvim-tree/nvim-web-devicons.git')
init.packadd('https://github.com/ibhagwan/fzf-lua.git')

vim.keymap.set('i', '<C-f>', function()
  local fzf_path = require('fzf-lua.path')
  require('fzf-lua').files({
    actions = {
      ['default'] = function(selected, opts)
        local entry = fzf_path.entry_to_file(selected[1], opts)
        local relpath = fzf_path.relative_to(entry.path, vim.uv.cwd())
        vim.api.nvim_put({ relpath }, 'c', true, true)
      end,
    },
  })
end)

