scriptencoding utf-8
let s:flash = v:true
let s:sneak = s:flash ? v:false : v:true

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
" vim-sneak is only wanted when flash is not (see s:sneak above), and in that
" case it is not in 'runtimepath' at all.
if s:sneak
  call init#packadd('https://github.com/justinmk/vim-sneak.git')
endif

" flash.nvim ships no plugin/ file, so these mappings are set directly.
nnoremap s <Cmd>lua require('flash').jump()<CR>
xnoremap s <Cmd>lua require('flash').jump()<CR>
onoremap s <Cmd>lua require('flash').jump()<CR>
nnoremap S <Cmd>lua require('flash').treesitter()<CR>
xnoremap S <Cmd>lua require('flash').treesitter()<CR>
onoremap S <Cmd>lua require('flash').treesitter()<CR>

call init#packadd('https://github.com/folke/flash.nvim.git')
