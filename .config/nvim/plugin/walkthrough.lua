vim.api.nvim_create_user_command('Walkthrough', function(o)
  require('walkthrough').load(o.args)
end, { nargs = 1, complete = 'file', desc = 'Load a Lua diff-walkthrough spec into quickfix, notes as virtual lines' })

vim.api.nvim_create_user_command('WalkthroughClose', function()
  require('walkthrough').close()
end, { desc = 'Clear walkthrough notes, images, scope bar and folds' })
