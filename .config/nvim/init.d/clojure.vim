" Update the static files for clojure from it's upstream,
" this includes fixes like indenting #() properly.
call init#packadd('https://github.com/clojure-vim/clojure.vim.git')

" This plugin allows you to manipulate sexp (clojure
" parens) in magical ways.
lua << EOF
local init = require('init')
local filetypes = {'clojure', 'scheme', 'lisp', 'timl', 'fennel'}
local filetype_set = {}
for _, filetype in ipairs(filetypes) do
  filetype_set[filetype] = true
end
local loaded = false
local function packadd_sexp()
  if loaded then
    return
  end
  loaded = true
  vim.cmd.packadd('vim-sexp')
  vim.cmd.packadd('vim-sexp-mappings-for-regular-people')
end
vim.api.nvim_create_autocmd({'BufReadPre', 'BufNewFile'}, {
  pattern = '*',
  callback = function(ev)
    local filetype = vim.bo[ev.buf].filetype
    if filetype == '' then
      filetype = vim.filetype.match({buf = ev.buf, filename = ev.file})
    end
    if filetype_set[filetype] then
      packadd_sexp()
    end
  end,
})
vim.api.nvim_create_autocmd('FileType', {
  pattern = filetypes,
  once = true,
  nested = true,
  callback = packadd_sexp,
})
init.packadd({ src = 'https://github.com/guns/vim-sexp.git', version = 'master' }, { load = function() end })
EOF
let g:sexp_regput_fallback_source = 'o'
" When pasting into a comment or string, don't use special sexp-aware paste behaviour
let g:sexp_regput_fallback_target = 'cs'
" Pasting when on a open/closing bracket will paste into head/tail rather than "put into list", meaning [count]
" specifies number of pastes into that position, rather than position in that list.
let g:sexp_regput_bracket_is_target = 2

" By default == has a maximum number of lines to prevent
" hanging. Disable that, because I'm happy to wait when I
" want this.
let g:clojure_maxlines = 0

" g:campfire selects vim-campfire over vim-fireplace. Set by
" ~/.config/nvim/campfire.vim launcher (-u campfire.vim).
let s:campfire = get(g:, 'campfire', 0) ? v:true : v:false
let s:fireplace = s:campfire ? v:false : v:true

" FiREPLace is a plugin for integrating with a Clojure
" nREPL.
if s:fireplace
  call init#packadd(#{src: 'https://github.com/SevereOverfl0w/vim-fireplace.git', version: 'dominic/patches'})
endif
" Disable auto-nashorn
let g:fireplace_cljs_repl = ''

" vim-campfire: alternative nREPL client used when g:campfire=1.
if s:campfire
  call init#packadd('https://github.com/SevereOverfl0w/campfire.nvim.git', #{load: s:campfire})
endif
" TODO: add none-ls here
function! s:configure_none_ls() abort
    lua <<EOF
local null_ls = require('null-ls')

local sources = {
  null_ls.builtins.completion.spell,
}
local campfire_none_ls_ok, campfire_none_ls = pcall(require, 'campfire.none_ls')
if campfire_none_ls_ok then
  vim.list_extend(sources, campfire_none_ls.sources())
end

null_ls.setup({ sources = sources })
EOF
endfunction

call init#packadd('https://github.com/nvim-lua/plenary.nvim.git')
call init#packadd('https://github.com/nvimtools/none-ls.nvim.git')
call s:configure_none_ls()

let g:FIREPLACE_PRINT_META = get(g:, 'FIREPLACE_PRINT_META', v:true)

function! Pprint_fun(msg, width)
  let opts = #{}
  if g:FIREPLACE_PRINT_META
    let opts['print-meta'] = v:true
  endif
  call fireplace#pprint_puget(a:msg, a:width, opts)
endfunction

let g:Fireplace_pprint_func = 'Pprint_fun'

" REPLant is a plugin for enhancing your REPL experience
" with vim.
if s:fireplace
  call init#packadd('https://github.com/SevereOverfl0w/vim-replant.git')
endif

" A plugin for managing nREPL middleware and starting the
" nREPL.
function! s:configure_jack_in() abort
  let g:jack_in_injections['cider/piggieback'] =
      \  {'version': '0.5.3',
      \   'middleware': 'cider.piggieback/wrap-cljs-repl'}

  let g:jack_in_injections['refactor-nrepl/refactor-nrepl']['version'] = '3.6.0'
  let g:jack_in_injections['cider/cider-nrepl']['version'] = '0.29.0'

  let g:jack_in_injections['io.dominic/nrepl-bind'] =
              \  {'version': '0.1.1',
              \   'middleware': 'io.dominic.nrepl-bind/wrap-bind'}
  " let g:jack_in_injections['io.dominic/nrepl-bind'] = {'middleware': 'io.dominic.nrepl-bind/wrap-bind'}

  if exists('*Local_Jack_In')
      call Local_Jack_In()
  endif
endfunction

call init#after_source('*/plugin/jack_in.vim', function('s:configure_jack_in'))
call init#packadd('https://github.com/clojure-vim/vim-jack-in.git')

let s:setup = []
function! s:SetupBind()
    if !fireplace#op_available('eval')
        return
    endif
    let id = fireplace#clj().Client().session.url
    if index(s:setup, id) == -1
        let Eval = fireplace#clj().Eval
        " TODO: Changes *1, so not ideal.  Probably need to add an op to
        " nrepl-bind instead.
        call Eval("(ns io.dominic.mise.vim) (io.dominic.nrepl-bind/try-bind-vars matcher-combinators.ansi-color/*use-color*)")
        call Eval("(ns io.dominic.mise.vim) (when (resolve 'matcher-combinators.ansi-color/*use-color*) (eval '(set! matcher-combinators.ansi-color/*use-color* false)))")
        call add(s:setup, id)
    endif
endfunction

" Prevent fireplace from creating tag bindings, in favour of using LSP with a tagfunc
let g:nremap = get(g:, 'nremap', {})
call extend(g:nremap, {
      \ '<C-]>': '',
      \ 'g<LeftMouse>': '',
      \ '<C LeftMouse>': '',
      \ 'g]': '',
      \ 'g<C-]>': '',
      \ '<C-W>]': '',
      \ '<C-W><C-]>': '',
      \ '<C-W>g]': '',
      \ '<C-W>g<C-]>': '',
      \ })

if s:fireplace
  augroup FireplaceCustom
      autocmd!
      autocmd FileType clojure call s:SetupBind()
      autocmd User FireplaceActivate call s:SetupBind()
  augroup END
endif


" async-clj-omni is an auto-completion plugin for
" clojure
if s:fireplace
  call init#packadd('https://github.com/clojure-vim/async-clj-omni.git')
endif

" augroup ClojureLint
" autocmd!
" autocmd BufWritePost *.clj silent Make
" augroup END
" }}}
