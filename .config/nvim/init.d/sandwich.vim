" vim-sandwich looks at vim-surround and says "ha, that is
" no true operator", and fixes that.

" The default key mappings collide with s from vim-sneak,
" so bind them behind leader.  I don't use them too often,
" so I don't think it's a massive loss having them be 3
" keypresses away instead of 2.
let g:sandwich_no_default_key_mappings = 1
let g:operator_sandwich_no_default_key_mappings = 1

function! s:configure_sandwich() abort
  " Sandwich has this cute highlighting trick where it shows
  " the thing it's deleting/surrounding in a special
  " highlight. The only duration that enables you to see this
  " is 200ms. For deletes this makes them feel slow, and you
  " can barely see it, so disable highlighting for delete.
  call operator#sandwich#set('delete', 'all', 'highlight', 0)

  " Recipe list:
  " - In vim files, `pg` will surround the snippet as `Plug '%s'` for
  "   integration with vim-plug
  " - In adoc files kbd:[] macro available
  let s:local_recipes = [
        \ {'__filetype__': 'vim', 'buns': ["call init#packadd('", "')"], 'input': [ 'pg' ], 'filetype': ['vim']},
        \ {'__filetype__': 'vim', 'buns': ["zeno#github('", "')"], 'input': [ 'zn' ], 'filetype': ['vim']},
        \ {'__filetype__': 'asciidoc', 'buns': ['kbd:[', ']'], 'input': [ 'kbd' ], 'filetype': ['asciidoc']}]
  " Adding custom recipes involves copying the default
  " recipes and adding.
  let g:sandwich#recipes = deepcopy(sandwich#get_recipes())
  let g:sandwich#recipes += s:local_recipes

  silent! nmap <unique><silent> <leader>sd <Plug>(operator-sandwich-delete)<Plug>(operator-sandwich-release-count)<Plug>(textobj-sandwich-query-a)
  silent! nmap <unique><silent> <leader>sr <Plug>(operator-sandwich-replace)<Plug>(operator-sandwich-release-count)<Plug>(textobj-sandwich-query-a)
  silent! nmap <unique><silent> <leader>sdb <Plug>(operator-sandwich-delete)<Plug>(operator-sandwich-release-count)<Plug>(textobj-sandwich-auto-a)
  silent! nmap <unique><silent> <leader>srb <Plug>(operator-sandwich-replace)<Plug>(operator-sandwich-release-count)<Plug>(textobj-sandwich-auto-a)

  " add
  silent! nmap <unique> <leader>sa <Plug>(operator-sandwich-add)
  silent! xmap <unique> <leader>sa <Plug>(operator-sandwich-add)
  silent! omap <unique> <leader>sa <Plug>(operator-sandwich-g@)
  silent! xmap <unique> <leader>sd <Plug>(operator-sandwich-delete)
  silent! xmap <unique> <leader>sr <Plug>(operator-sandwich-replace)
endfunction

call init#after_source('*/plugin/sandwich.vim', function('s:configure_sandwich'))
call init#packadd('https://github.com/machakann/vim-sandwich.git')
