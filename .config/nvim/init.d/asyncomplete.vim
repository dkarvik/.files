if exists('g:init_loaded_asyncomplete')
  finish
endif

" Read by asyncomplete.vim while its plugin/ file is sourced
let g:asyncomplete_auto_completeopt = 0

call init#packadd('https://github.com/prabirshrestha/asyncomplete.vim.git')
call init#packadd('https://github.com/ncm2/float-preview.nvim.git')
call init#packadd('https://github.com/yami-beta/asyncomplete-omni.vim.git')

au User asyncomplete_setup call asyncomplete#register_source({
    \ 'name': 'async_clj_omni',
    \ 'whitelist': ['clojure'],
    \ 'completor': function('async_clj_omni#sources#complete'),
    \ })

autocmd User asyncomplete_setup call asyncomplete#register_source(asyncomplete#sources#omni#get_source_options({
\ 'name': 'omni',
\ 'allowlist': ['todo'],
\ 'completor': function('asyncomplete#sources#omni#completor'),
\ 'config': {
\   'show_source_kind': 1,
\ },
\ }))

" https://github.com/prabirshrestha/asyncomplete.vim/issues/117
inoremap <expr> <CR> pumvisible() ? asyncomplete#close_popup() . "\<CR>" : "\<CR>"

set completeopt-=preview
