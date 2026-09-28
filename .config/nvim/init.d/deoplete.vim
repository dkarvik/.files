if exists('g:init_loaded_deoplete')
  finish
endif

function! s:configure_deoplete() abort
  " TODO: This doesn't seem to cover all possible cases where
  " terraform can do completions.
  call deoplete#custom#var('omni', 'input_patterns', {
      \ 'terraform': '[^ *\t"{=$]\w*',
      \})
endfunction

call init#after_source('*/plugin/deoplete.vim', function('s:configure_deoplete'))

" These are read by deoplete while its plugin/ file is sourced, so they have
" to be set before the plugin is added.

" It isn't enabled by default, so start it up
let g:deoplete#enable_at_startup = 1

" I set some deoplete patterns later on for filetypes
let g:deoplete#keyword_patterns = {}
let g:deoplete#keyword_patterns.clojure = '[\w!$%&*+/:<=>?@\^_~\-\.#]*'
let g:deoplete#omni_patterns = {}

" Deoplete provides asyncronous as-you-type completions
call init#packadd('https://github.com/Shougo/deoplete.nvim.git')
