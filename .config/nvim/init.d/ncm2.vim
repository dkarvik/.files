if exists('g:init_loaded_ncm2')
  finish
end

" enable ncm2 for all buffers
function! s:configure_ncm2() abort
  augroup activate_ncm2
    au!
    autocmd BufEnter * call ncm2#enable_for_buffer()
  augroup END

  " IMPORTANT: :help Ncm2PopupOpen for more information
  set completeopt=noinsert,menuone,noselect

  au User Ncm2Plugin call ncm2#register_source({
          \ 'name' : 'todo',
          \ 'priority': 9,
          \ 'scope': ['todo'],
          \ 'mark': 'todo',
          \ 'word_pattern': '[+@]\S+',
          \ 'complete_length': -1,
          \ 'complete_pattern': '[+@]',
          \ 'on_complete': ['ncm2#on_complete#omni', 'todo#Complete'],
          \ })

  au User Ncm2Plugin call ncm2#register_source({
      \ 'name' : 'zk',
      \ 'priority': 9,
      \ 'scope': ['markdown'],
      \ 'mark': 'ZK',
      \ 'complete_pattern': ['\[\[', '#'],
      \ 'on_complete': 'ncm2#on_complete#lsp',
      \ })
endfunction

call init#packadd('https://github.com/ncm2/ncm2.git')
call s:configure_ncm2()
call init#packadd('https://github.com/roxma/nvim-yarp.git')
" float-preview.nvim is declared in asyncomplete.vim.

