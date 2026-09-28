-- nvim-cmp group. Loaded at startup; cmp's own plugin file does most of the
-- work and the sources self-register via their after/plugin scripts.

if vim.g.init_loaded_cmp then
  return
end

local init = require('init')

local cmp_loaded = false
local function load_cmp()
  if cmp_loaded then
    return
  end
  cmp_loaded = true
  vim.api.nvim_create_autocmd('InsertEnter', {
    once = true,
    callback = function()
      vim.cmd.packadd('nvim-cmp')
      vim.cmd.packadd('cmp-nvim-lsp')
      vim.cmd.packadd('cmp-buffer')
      vim.cmd.packadd('cmp-emoji')
    end,
  })
end

init.after_source('*/plugin/cmp.lua', function()
  local cmp = require('cmp')
  cmp.setup({
    mapping = cmp.mapping.preset.insert(),
    sources = {
      { name = 'buffer' },
      { name = 'async_clj_omni' },
      { name = 'campfire' },
      { name = 'nvim_lsp' },
    },
    snippet = {
      expand = function(args)
        vim.snippet.expand(args.body)
      end,
    },
  })
  cmp.setup.filetype({ 'markdown', 'gitcommit', 'markdown.nvim_reply_review' }, {
    sources = {
      { name = 'nvim_lsp' },
      { name = 'buffer' },
      { name = 'emoji' },
    },
  })
end)

init.packadd('https://github.com/hrsh7th/nvim-cmp.git', { load = load_cmp })
init.packadd('https://github.com/hrsh7th/cmp-nvim-lsp.git', { load = load_cmp })
init.packadd('https://github.com/hrsh7th/cmp-buffer.git', { load = load_cmp })
init.packadd('https://github.com/hrsh7th/cmp-emoji.git', { load = load_cmp })

