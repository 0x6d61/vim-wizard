set runtimepath^=.
runtime plugin/yank_and_slash.vim
VimWizard
call assert_equal([7, 3], [line('.'), col('.')])
call feedkeys('2', 'xt')
call assert_equal([8, 3], [line('.'), col('.')])
call feedkeys("\<CR>", 'xt')
call assert_equal([1, 1], [line('.'), col('.')])
call assert_equal(0, winsaveview().curswant)

call feedkeys('j', 'xt')
call assert_equal([2, 1], [line('.'), col('.')])
call assert_equal(1, b:ys.turn)

call yank_and_slash#restart()
call assert_equal([1, 1], [line('.'), col('.')])
call assert_equal(0, winsaveview().curswant)
call feedkeys('j', 'xt')
call assert_equal([2, 1], [line('.'), col('.')])

if !empty(v:errors)
  for error in v:errors | echomsg error | endfor
  cquit
endif
qa!
