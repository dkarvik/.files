let myUndoDir = fnamemodify(len($XDG_DATA_HOME) == 0 ? '~/.local/share' : $XDG_DATA_HOME, ':p:h') . '/nvim/myundodir'
call mkdir(myUndoDir, 'p')
let &undodir = myUndoDir
set undofile
