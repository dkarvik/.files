call init#packadd('https://gitlab.com/dbeniamine/todo.txt-vim.git')

" Quickly jump to the root of the wiki in a tab
nnoremap <leader>wW :<C-U>tabnew \| tcd ~/doc/<CR>

nnoremap <leader>tG : ~/doc/todo.txt<Home>vimgrep<space>
nnoremap <leader>tj :<C-U>10split ~/doc/todo.txt<CR>

" Improve markdown support

map <leader>to  <Plug>(operator-add-todo)
map <leader>tO  <Plug>(operator-prompt-todo)

nnoremap <leader>tA :<C-U>AddTodo<space>

command! -nargs=* AddTodo call s:AppendToFile(expand('~/doc/todo.txt'), [join([<q-args>], ' ')])

function! s:define_todo_operators() abort
  call operator#user#define('add-todo', 'Add_todo')
  call operator#user#define('prompt-todo', 'Prompt_todo')
endfunction

" vim-operator-user is declared in misc.vim, which sources before this file,
" so its autoload functions already resolve.
call s:define_todo_operators()

function! Add_todo(motion_wise)
  let v = operator#user#visual_command_from_wise_name(a:motion_wise)

  let [original_U_content, original_U_type] = [@", getregtype('"')]
    execute 'normal!' '`['.v.'`]y'
    let keyword = @"
  call setreg('"', original_U_content, original_U_type)

  call s:AppendToFile(expand('~/doc/todo.txt'), [keyword . ''])
endfunction

function! Prompt_todo(motion_wise)
  let v = operator#user#visual_command_from_wise_name(a:motion_wise)

  let [original_U_content, original_U_type] = [@", getregtype('"')]
    execute 'normal!' '`['.v.'`]y'
    let keyword = @"
  call setreg('"', original_U_content, original_U_type)

  call feedkeys(":\<C-U>AddTodo " . keyword)
endfunction

function! s:AppendToFile(file, lines)
    call writefile(readfile(a:file)+a:lines, a:file)
endfunction

" Stolen from https://stackoverflow.com/a/4294176
" Affects more than the wiki.  TBD where this will live.
function! s:MkNonExDir(file, buf)
    if empty(getbufvar(a:buf, '&buftype')) && a:file!~#'\v^\w+\:\/'
        let dir=fnamemodify(a:file, ':h')
        if !isdirectory(dir)
            call mkdir(dir, 'p')
        endif
    endif
endfunction
augroup BWCCreateDir
    autocmd!
    autocmd BufWritePre * :call s:MkNonExDir(expand('<afile>'), +expand('<abuf>'))
augroup END
