" call init#packadd('neomake/neomake')
"
" function Hook_post_source_neomake()
"     call neomake#configure#automake('nrwi', 500)
" endfunction
"
" let g:neomake_voidtemplate_xlint_maker = {
"       \ 'exe': 'xlint',
"       \ 'errorformat': '%f:%l: %m',
"       \ 'auto_enabled': 1,
"       \}
"
" let g:neomake_voidtemplate_enabled_makers = ['xlint']
"
" " javac is slow, due to maven shell out
" " https://github.com/neomake/neomake/issues/875
" " javac is the only java maker
" let g:neomake_java_enabled_makers = []
