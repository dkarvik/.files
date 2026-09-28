" vim-grepper helps you win at grep, integrated with the
" quickfix

" vim-grepper reads g:grepper while its plugin/ file is sourced, so the
" config has to come before the plugin is added.
let g:grepper = {}
" Change the preferred ordering of tools, ripgrep works better than git-grep
" in most cases. e.g. untracked files
let g:grepper.tools = ['git', 'grep']
if executable('grape')
  call insert(g:grepper.tools, 'grape')
  let g:grepper.grape = {
        \ 'grepprg': 'grape --inline $* .',
        \ 'grepprgbuf': 'grape --inline $* $.',
        \ 'grepformat': '%+P%f:,%l: %m,%-Q'
        \ }
endif

if executable('ag')
  call insert(g:grepper.tools, 'ag')
endif
if executable('rg')
  call insert(g:grepper.tools, 'rg')
endif

" I took the default value for this and added
" - `-L` to follow symlinks.
" - `--hidden` to search .files
" - `-S` smart casing
" - --max-columns=150 to prevent extremely long lines
"   crashing vim
let g:grepper.rg = get(g:grepper, 'rg', {})
let g:grepper.rg.grepprg = "rg -H -L --hidden -S -g '!.git' -g '!.stversions' --max-columns=150 --no-heading --vimgrep"
let g:grepper.simple_prompt = 1

call init#packadd('https://github.com/mhinz/vim-grepper.git')

" An operator for grepping. Allows me to do `<leader>GiW` or
" `<leader>Gie`, etc. to grep for a text object.
nmap <leader>G <plug>(GrepperOperator)
xmap <leader>G <plug>(GrepperOperator)
noremap <leader>/ :<C-u>Grepper<CR>

for dirmap in get(g:, 'dirs_of_interest', [])
  execute 'noremap '. dirmap.prefix . '/ <cmd>Grepper -cd '. dirmap['directory'] .'<CR>'
endfor
