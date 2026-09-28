function! init#run() abort
  runtime! init.d/*.vim init.d/*.lua
endf

function! init#packadd(src, ...) abort
  call luaeval("require('init').packadd(_A[1], _A[2])", [a:src, a:0 ? a:1 : v:null])
endf

let s:after_source_ids = {}
let s:after_source_callbacks = {}
let s:after_source_serial = 0

function! s:after_source_run(id) abort
  call call(s:after_source_callbacks[a:id], [])
endf

function! init#after_source(pattern, callback) abort
  let id = get(s:after_source_ids, a:pattern, 0)
  if id == 0
    let s:after_source_serial += 1
    let id = s:after_source_serial
    let s:after_source_ids[a:pattern] = id
  endif
  let s:after_source_callbacks[id] = a:callback

  execute printf('augroup init_after_source_%d', id)
  autocmd!
  execute printf('autocmd SourcePost %s ++once call <SID>after_source_run(%d)', a:pattern, id)
  augroup END
endf
