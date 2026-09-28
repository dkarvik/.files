call init#packadd('https://github.com/preservim/vim-markdown.git')

let g:vim_markdown_follow_anchor = 1
let g:vim_markdown_new_list_item_indent = 2
let g:vim_markdown_autowrite = 1
let g:vim_markdown_folding_style_pythonic = 1

call init#packadd('https://github.com/iamcco/markdown-preview.nvim.git')

function! s:install_markdown_preview() abort
  if v:event.data.spec.name ==# 'markdown-preview.nvim'
        \ && index(['install', 'update'], v:event.data.kind) >= 0
    lua vim.system({'yarn', 'install'}, {cwd = vim.v.event.data.path .. '/app'}):wait()
  endif
endfunction

augroup init_markdown_preview
  autocmd!
  autocmd PackChanged * call s:install_markdown_preview()
augroup END

call init#packadd('https://github.com/dhruvasagar/vim-table-mode.git')
