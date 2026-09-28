-- twilight.nvim is loaded at startup; setup is explicit.

local init = require('init')

init.after_source('*/plugin/twilight.vim', function()
  require('twilight').setup({
    context = 3,
    expand = {
      'list_lit',
      'map_lit',
    },
  })
end)

init.packadd('https://github.com/folke/twilight.nvim.git')
