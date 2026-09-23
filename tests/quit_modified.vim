set runtimepath^=.
runtime plugin/yank_and_slash.vim
let original = bufnr('%')
call setline(1, 'Unsaved work')
VimWizard
call feedkeys("\<CR>", 'xt')
try
  silent! call feedkeys(":q\<CR>", 'xt')
catch
endtry
call assert_equal(original, bufnr('%'))
call assert_equal(1, getbufvar(original, '&modified'))
call assert_equal('Unsaved work', getbufline(original, 1)[0])
if !empty(v:errors)
  for error in v:errors | echomsg error | endfor
  cquit
endif
qa!
