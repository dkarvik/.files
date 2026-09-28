if exists('g:init_loaded_coc')
  finish
endif

call init#packadd(#{src: 'https://github.com/neoclide/coc.nvim.git', version: 'release'})
