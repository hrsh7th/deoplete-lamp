if exists('g:deoplete_lamp_loaded')
  finish
endif
let g:deoplete_lamp_loaded = 1

augroup deoplete_lamp
  autocmd!
  autocmd InsertLeave * call deoplete_lamp#clear()
augroup END

