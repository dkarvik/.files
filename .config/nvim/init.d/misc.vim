" call init#packadd('ap/vim-css-color')

function! s:configure_colorizer() abort
  lua require'colorizer'.setup()
endfunction

call init#after_source('*/plugin/colorizer.lua', function('s:configure_colorizer'))
call init#packadd('https://github.com/catgoose/nvim-colorizer.lua.git')

" A few plugins require this plugin in order to make their
" own operators.  More than just those in operators.
" Consumers define their operators themselves (see wiki.vim).
call init#packadd('https://github.com/kana/vim-operator-user.git')

" This is both a utility and dependency of a few plugins
" (fugitive, rhubarb, jack-in)
call init#packadd('https://github.com/tpope/vim-dispatch.git')

" seed the dispatch compilers so that later groups can set
" keys in it
let g:dispatch_compilers = {}

" This provides dispatch with a neovim :terminal based
" interface. This means that `:Start` will open a terminal
" in a tab.
" call init#packadd('radenling/vim-dispatch-neovim')

" This plugin extends the functionality of `.`.  I added it
" initially for support with >) from vim-sexp, but
" vim-sneak and many others also use it.
call init#packadd('https://github.com/tpope/vim-repeat.git')

" Some plugins require this in order to figure out the
" contextual filetype (e.g. in a [source] block in
" asciidoc, or in ```clojure in markdown) Plug
" Used by:
" - deoplete
" call init#packadd('Shougo/context_filetype.vim')

call init#packadd('https://github.com/tpope/vim-sleuth.git')

call init#packadd('https://github.com/lepture/vim-jinja.git')

call init#packadd('https://github.com/tpope/vim-scriptease.git')

call init#packadd('https://github.com/ziglang/zig.vim.git')

call init#packadd('https://github.com/zaid/vim-rec.git')

call init#packadd('https://github.com/tpope/vim-speeddating.git')

call init#packadd('https://github.com/tpope/vim-eunuch.git')

call init#packadd('https://github.com/rhysd/conflict-marker.vim.git')

let g:textobj_diff_no_default_key_mappings = 1
" vim-textobj-diff is never loaded at startup; the FileType diff autocmd
" below packadds it (and vim-textobj-user) on demand.

augroup init_textobj_diff
  autocmd!
  autocmd FileType diff ++once packadd vim-textobj-user | packadd vim-textobj-diff
augroup END

" `:Git status` diffs include trailing whitespace for the diff.  So does `:Git show HEAD`
let g:extra_whitespace_ignored_filetypes = ['fugitive', 'git', 'gitcommit']
call init#packadd('https://github.com/bronson/vim-trailing-whitespace.git')

call init#packadd('https://github.com/tpope/vim-flagship.git')
let g:tabprefix = ''

function! Filename(bufnr) abort
  let buftype = getbufvar(a:bufnr, "&buftype")
  let f = getbufinfo(a:bufnr)[0].name
  if buftype ==# 'quickfix'
    return '[Quickfix List]'
  elseif buftype =~# '^\%(nofile\|acwrite\|terminal\)$'
    return empty(f) ? '[Scratch]' : f
  elseif empty(f)
    return '[No Name]'
  elseif buftype ==# 'help'
    return fnamemodify(f, ':t')
  endif
  let ns = substitute(matchstr(f, '^\a\a\+\ze:'), '^\a', '\u&', 'g')
  if len(ns) && exists('*' . ns . 'Real')
    try
      let f2 = {ns}Real(f)
      if !empty(f2)
        let f = f2
      endif
    catch
    endtry
  endif

  return f
endfunction

function! MaybeTabCwds(...)
    let args = copy(a:000)
    let tabnr = type(get(args, 0, '')) == type(0) ? remove(args, 0) : v:lnum
    let tabinfo = gettabinfo(tabnr)[0]

    let difftabs = []
    for windowid in tabinfo.windows
        if gettabwinvar(tabnr, windowid, 'fugitive_diff_restore')
            call add(difftabs, windowid)
        endif
    endfor

    if len(difftabs) == 2
        let f = FugitiveReal(getbufinfo(getwininfo(difftabs[0])[0].bufnr)[0].name)
        return pathshorten(fnamemodify(f, ':.'), 1)
    elseif len(tabinfo.windows) == 1
        return pathshorten(fnamemodify(Filename(getwininfo(tabinfo.windows[0])[0].bufnr), ':~:.'))
    else
        return flagship#tabcwds(tabnr, 'shorten',',')
    endif
endfunction
let g:tablabel = '%N%{flagship#tabmodified()} %{MaybeTabCwds()}'

function! MaybeActivateBaleia(baleia)
    if get(w:, 'quickfix_title', '') =~? 'clojure.test'
        setlocal modifiable undolevels=-1
        silent call a:baleia.once(bufnr('%'))
        setlocal nomodifiable nomodified
    endif
endfunction

function! s:configure_baleia() abort
  let s:baleia = luaeval("require('baleia').setup({ strip_ansi_codes = false })")
  let s:baleia_strips = luaeval("require('baleia').setup()")
  command! BaleiaColorize call s:baleia.once(bufnr('%'))
  command! BaleiaLogs call s:baleia.logger.show()
  augroup BaleiaUser
    autocmd!
    autocmd BufReadPost quickfix call MaybeActivateBaleia(s:baleia_strips)
    autocmd BufWinEnter quickfix call MaybeActivateBaleia(s:baleia_strips)
  augroup END
endfunction

call init#packadd(#{src: 'https://github.com/m00qek/baleia.nvim.git', version: 'v1.4.0'})
call s:configure_baleia()

" call init#packadd('powerman/vim-plugin-ansiesc')

function! s:configure_nvim_treesitter() abort
  lua require'nvim-treesitter'.install({"lua", "vim", "vimdoc", "bash", "clojure"})
  augroup treesitter_start
          autocmd!
          autocmd FileType lua,vim,help,bash,clojure call v:lua.vim.treesitter.start(str2nr(expand('<abuf>')))
  augroup END
endfunction

call init#after_source('*/plugin/nvim-treesitter.lua', function('s:configure_nvim_treesitter'))
call init#packadd(#{src: 'https://github.com/nvim-treesitter/nvim-treesitter.git', version: 'main'})

call init#packadd(#{src: 'https://github.com/SevereOverfl0w/nvim-treesitter-endwise.git', version: 'nvim-0.12'})

call init#packadd('https://github.com/AndrewRadev/inline_edit.vim.git')

call init#packadd('https://github.com/Apeiros-46B/qalc.nvim.git')

call init#packadd('https://github.com/terrastruct/d2-vim.git')

function! s:configure_send_to_term() abort
  nmap <leader>st <Plug>Send
  vmap <leader>st <Plug>Send
endfunction

call init#after_source('*/plugin/send-to-term.vim', function('s:configure_send_to_term'))
let g:send_disable_mapping = 1
call init#packadd('https://github.com/mtikekar/nvim-send-to-term.git')

call init#packadd('https://github.com/aymericbeaumet/vim-symlink.git')

call init#packadd('https://github.com/moll/vim-bbye.git')

call init#packadd('https://github.com/nvim-treesitter/nvim-treesitter-context.git')

call init#packadd(#{src: 'https://github.com/SevereOverfl0w/annotator.nvim.git', version: 'qfs'})

call init#packadd('https://github.com/digitaltoad/vim-pug.git')

call init#packadd('https://github.com/folke/ts-comments.nvim.git')

call init#packadd('https://github.com/purarue/yadm-git.vim.git')

" lua <<EOF
" vim.g.diffs = {
"   integrations = {
"     fugitive = true,
"     difftastic = true,
"   },
" }
" EOF

" call init#packadd('barrettruth/diffs.nvim')
