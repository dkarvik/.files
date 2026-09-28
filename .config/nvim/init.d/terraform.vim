" vim-terraform "fixes" syntax detection for *.tf to be
" terraform files
call init#packadd('https://github.com/hashivim/vim-terraform.git')

" Provides:
" - Contextual completions with deoplete support
" - Automatic linting via syntastic or neomake
" - Tagbar integration
" - Keybindings for docs
" For now I am mostly using the completion though.
" Disable slow registry search for auto-completion
let g:terraform_module_registry_search = 0

call init#packadd('https://github.com/juliosueiras/vim-terraform-completion.git')
