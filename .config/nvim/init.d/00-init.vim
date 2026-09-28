" Leader keys are important, because you bang on them all
" day They go first so that mappings after this point
" respect them
let mapleader=' '
let maplocalleader=','

" Enable true colour (16 million instead of 256) support
set termguicolors

" Set the clipboard to be the same as the system's
" clipboard, not vim's internal one:
set clipboard+=unnamedplus

" Reduce updatetime, the most visible effect is making
" gitgutter more responsive.  But also controls swap file
" write frequency.
set updatetime=100

" Configure replacements (e.g. :s) to show a preview of
" what's changing
set inccommand=split

set completeopt=menuone,preview,noinsert,noselect

set expandtab " Spaces, not tabs
set shiftwidth=4 " Indent
set softtabstop=4 " Tab key

" Navigating between lines for operations with jk for
" example
set number relativenumber

" Inside of neovim terminals, set the editor to nvr so I
" don't open a nested neovim.
if executable('nvr')
  let $VISUAL = 'nvr -cc split --remote-wait'
endif

set signcolumn=auto:2

nmap ]a <Cmd>next<CR>
nmap [a <Cmd>previous<CR>
nmap ]oh <Cmd>nohlsearch<CR>

if has('nvim-0.9.0')
    set diffopt+=linematch:60
endif

set textwidth=100

nmap ZB <CMD>Bdelete<CR>

nnoremap gl <cmd>call v:lua.vim.diagnostic.open_float()<cr>
lua vim.diagnostic.config({ virtual_text = { current_line = true } })

" Build hooks live here, not beside their plugins: the first vim.pack.add()
" installs everything missing from the lockfile, and PackChanged must already
" be registered to see those installs.
lua << EOF
vim.api.nvim_create_autocmd('PackChanged', {
  group = vim.api.nvim_create_augroup('init_markdown_preview', {}),
  callback = function(ev)
    local d = ev.data
    if d.spec.name == 'markdown-preview.nvim' and (d.kind == 'install' or d.kind == 'update') then
      vim.system({ 'yarn', 'install' }, { cwd = d.path .. '/app' }):wait()
    end
  end,
})
EOF
