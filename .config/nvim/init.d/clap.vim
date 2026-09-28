if exists('g:init_loaded_clap')
  finish
endif

call init#packadd('https://github.com/liuchengxu/vim-clap.git')

nnoremap <Leader>jf <Cmd>Clap files<cr>

for dirmap in get(g:, 'dirs_of_interest', [])
  execute 'nnoremap '. dirmap.prefix . 'f <cmd>Clap files '. dirmap['directory'] .'<CR>'
endfor

noremap <leader>b <Cmd>Clap buffers<cr>
noremap <leader>B <Cmd>Clap blines<cr>
noremap <leader>L <Cmd>Clap lines<cr>
