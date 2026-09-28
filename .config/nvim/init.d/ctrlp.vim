if exists('g:init_loaded_ctrlp')
  finish
endif

" Read by ctrlp.vim while its plugin/ file is sourced: it registers its
" default <c-p> mapping unless `g:ctrlp_map` is set beforehand.
let g:ctrlp_map = ''

call init#packadd('https://github.com/ctrlpvim/ctrlp.vim.git')

nnoremap <Leader>jf <Cmd>CtrlPMixed<CR>
nnoremap <Leader>b <Cmd>CtrlPBuffer<CR>
nnoremap <Leader>B <Cmd>CtrlPLine<CR>

for dirmap in get(g:, 'dirs_of_interest', [])
  execute 'nnoremap '. dirmap.prefix . 'f <cmd>CtrlP ' . dirmap['directory'] .'<CR>'
endfor
