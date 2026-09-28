if exists('g:init_loaded_mucomplete')
  finish
end

" Read by mucomplete while its plugin/ file is sourced
let g:mucomplete#enable_auto_at_startup = 1
call init#packadd('https://github.com/lifepillar/vim-mucomplete.git')
