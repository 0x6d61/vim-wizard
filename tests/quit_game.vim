set runtimepath^=.
runtime plugin/yank_and_slash.vim
VimWizard
call feedkeys("\<CR>", 'xt')
call assert_equal(2, winnr('$'))
call feedkeys(":q\<CR>", 'xt')
" If :q only closes one window, this line makes the test fail.
cquit
