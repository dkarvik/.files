call init#packadd('https://github.com/miikanissi/modus-themes.nvim.git')
" onehalf keeps its colorschemes in a vim/ subdirectory.
lua <<EOF
require('init').packadd('https://github.com/sonph/onehalf.git', {
  load = function(plug_data)
    vim.opt.rtp:append(plug_data.path .. '/vim')
  end,
})
EOF
call init#packadd('https://gitlab.com/protesilaos/tempus-themes-vim.git')
call init#packadd('https://github.com/NLKNguyen/papercolor-theme.git')

" [1] is the light scheme, [2] the dark one.
let s:preferred_color_scheme = get(g:, 'preferred_color_scheme', ['tempus-themes-vim', 'tempus_day', 'tempus_night'])

let g:PaperColor_Theme_Options = {
\   'theme': {
\     'default.light': {
\       'override': {
\         'linenumber_fg': ['#111', '000']
\       }
\     }
\   }
\ }

augroup ColorOverrides
  autocmd!
  autocmd ColorScheme onehalflight hi! link IncSearch PMenuSel
  autocmd ColorScheme onehalflight hi! link ClapCurrentSelection Function
  autocmd ColorScheme * highlight DiagnosticDeprecated guisp=Red gui=undercurl cterm=undercurl
augroup END

function! GetColorSchemeForBackground()
  return &background ==# 'dark' ? s:preferred_color_scheme[2] : s:preferred_color_scheme[1]
endfunction

function! ReactBackgroundChange()
  if len(s:preferred_color_scheme) > 2
    exe 'colorscheme '.GetColorSchemeForBackground()
  endif
endfunction

function! ActivatePreferredColorScheme()
  if $TERM !=# 'linux'
    let scheme = len(s:preferred_color_scheme) > 2 ? GetColorSchemeForBackground() : s:preferred_color_scheme[1]
    exe 'colorscheme '.scheme
    " AutoCmds not triggered during VimEnter / other autocmds
    exe 'doautocmd ColorScheme '.scheme
  endif
endf

augroup activate_preferred_color_scheme
  autocmd!
  autocmd VimEnter * ++once call ActivatePreferredColorScheme()
augroup END

augroup BackgroundHandler
  autocmd OptionSet background call ActivatePreferredColorScheme()
augroup END
