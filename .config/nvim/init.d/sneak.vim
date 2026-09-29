scriptencoding utf-8
let s:leap = v:true
let s:sneak = s:leap ? v:false : v:true

" sneak provides alternatives to f,F which:
" - Work across lines
" - Provides an awesome label mode which prompts for a
"   character
" - Very fast (compared to alternatives I've tried)

" Enable labels for jumping around
let g:sneak#label = 1

function! s:map_sneak() abort
 " By default, vim-sneak uses z for operator-pending mode,
 " and s for normal mode.  Unfortunately s collides with
 " vim-sandwich (sandwich).  I really want consistency for
 " my choice of mappings though.  vim-sneak is really
 " important, I use it more often than vim-sandwich.
 omap s <Plug>Sneak_s
 omap S <Plug>Sneak_S
  
 " vim-sneak doesn't rebind f,F,t,T by default to it's
 " slightly improved versions by default.  NOTE: vim-sneak
 " doesn't use label mode for these by default, see
 " |sneak-functions| for how to change that.
 map f <Plug>Sneak_f
 map F <Plug>Sneak_F
 map t <Plug>Sneak_t
 map T <Plug>Sneak_T

endfunction

" sindresorhus found the best prompt character in unicode,
" use it for vim-sneak's prompt
let g:sneak#prompt = '❯'

call init#after_source('*/plugin/sneak.vim', function('s:map_sneak'))
call init#packadd('https://github.com/justinmk/vim-sneak.git', #{load: s:sneak})

function! s:map_leap() abort
  omap s <Plug>(leap)
  nmap s <Plug>(leap)
  xmap s <Plug>(leap)
  map S <Plug>(leap-anywhere)
endfunction

call init#after_source('*/leap.nvim/plugin/init.lua', function('s:map_leap'))
call init#packadd('https://codeberg.org/andyg/leap.nvim', #{load: s:leap})
