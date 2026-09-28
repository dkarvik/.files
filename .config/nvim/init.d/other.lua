-- Setup runs on first use via wrapper commands registered once plugin/init.lua is sourced.
local init = require('init')

init.after_source('*/other.nvim/plugin/init.lua', function()
  local setup = function()
    require('other-nvim').setup({
      mappings = {
        {
          context = 'test',
          pattern = function(path)
            local match = vim.fn.matchlist(path, '\\v^(.*)/src/(.{-}_test)@!(.{-}).clj(.?)')
            if #match > 0 then
              return match
            end
          end,
          target = '%2/test/%4_test.clj%5',
        },
        {
          context = 'test',
          pattern = function(path)
            local match = vim.fn.matchlist(path, '\\v^(.*)/src/(.{-}_test)@!(.{-}).cljc')
            if #match > 0 then
              return match
            end
          end,
          target = '%2/test/%4_test.clj',
        },
        {
          context = 'implementation',
          pattern = '(.*)/test/(.*)_test.clj(.?)$',
          target = '%1/src/%2.clj%3',
        },
      },
    })
  end

  local configured = false
  local methods = {
    Other = 'open',
    OtherTabNew = 'openTabNew',
    OtherSplit = 'openSplit',
    OtherVSplit = 'openVSplit',
    OtherClear = 'clear',
  }
  for command, method in pairs(methods) do
    vim.api.nvim_create_user_command(command, function(opts)
      if not configured then
        setup()
        configured = true
      end
      require('other-nvim')[method](unpack(opts.fargs))
    end, { nargs = '*', bang = true })
  end
end)

init.packadd('https://github.com/rgroli/other.nvim.git')

