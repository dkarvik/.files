" The quickfix is so important, especially with vim-grepper.
" vim-qf is romainl's collection of hacks for the quickfix.
call init#packadd('https://github.com/romainl/vim-qf.git')
call init#packadd('https://github.com/yssl/QFEnter.git')

" Wrapping version of :cnext and :cprev, for qf and location
" list.
nmap ]q <Plug>(qf_qf_next)
nmap [q <Plug>(qf_qf_previous)

nmap ]l <Plug>(qf_loc_next)
nmap [l <Plug>(qf_loc_previous)

" Add some reasonable convenience mappings:
" - s horizontal split, v vertical split
" - p open in preview
" - o open entry and return
let g:qf_mapping_ack_style = 1
