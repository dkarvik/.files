" Operators allow you to perform actions (operations) on
" text objects and motions.  I collect additional generic
" ones to make my life easier.  A lot of them depend on
" vim-operator-user
" I'm trying to use the <Leader>o prefix (for operator).

" The replace operator allows you to replace an object with
" the value in the register (clipboard).
function! s:map_operator_replace() abort
  map <Leader>or <Plug>(operator-replace)
endfunction

call init#after_source('*/plugin/operator/replace.vim', function('s:map_operator_replace'))
call init#packadd('https://github.com/kana/vim-operator-replace.git')

" These plugins enhance the kind of things you can refer to. e.g. sentences,
" words, lines, indentation level.  vim-sneak could fit into this category,
" but it shines on it's own.

" This is a dependency of many textobjs for defining themselves.
call init#packadd('https://github.com/kana/vim-textobj-user.git')

" This adds a text object which refers to the whole buffer.  Pairs well with
" fireplace's `cp` motion, in place of doing `%:Eval`, and also with `=`.
"
" Defaults to binding `ae` and `ie`.  This is incompatible
" with vim-sexp though, so remap to aE and Ie.  I don't
" expected to use this mapping too much.
"
let g:textobj_entire_no_default_key_mappings = 1

function! s:map_textobj_entire() abort
  xmap aE <Plug>(textobj-entire-a)
  omap aE <Plug>(textobj-entire-a)
  xmap iE <Plug>(textobj-entire-i)
  omap iE <Plug>(textobj-entire-i)
endfunction

call init#after_source('*/plugin/textobj/entire.vim', function('s:map_textobj_entire'))

if !has('nvim-0.13')
  call init#packadd('https://github.com/kana/vim-textobj-entire.git')
endif

" Adds a text object which refers to the current line.
" Binds to `al` and `il` by default.  Only loaded before Neovim 0.13.
if !has('nvim-0.13')
  call init#packadd('https://github.com/kana/vim-textobj-line.git')
endif

" Wordmotion creates word definitions which surpass the
" default ones in utility.  The readme does a better job of
" explaining than I can.
let g:wordmotion_spaces=' '
call init#packadd('https://github.com/chaoren/vim-wordmotion.git')
