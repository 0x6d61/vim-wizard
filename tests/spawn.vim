scriptencoding utf-8
set runtimepath^=.
let g:vim_wizard_seed = 42
runtime plugin/yank_and_slash.vim
VimWizard
call feedkeys("\<CR>", 'xt')

setlocal modifiable
silent %delete _
call setline(1, [repeat('.', 40).'k>'])
setlocal nomodifiable nomodified
call cursor(1, 1)
let b:ys.turn = 0
let b:ys.history = []

for turn in range(1, 4)
  call yank_and_slash#act('yy', 1)
  call assert_equal(0, strlen(substitute(join(getline(1, '$')), '[^r]', '', 'g')))
endfor
call assert_equal(4, b:ys.turn)
call yank_and_slash#act('yy', 1)
call assert_equal(5, b:ys.turn)
call assert_equal(1, b:ys.spawned)
call assert_match('新しい敵', b:ys.message)
call assert_equal(1, strlen(substitute(join(getline(1, '$')), '[^r]', '', 'g')))
let first_spawn = getline(1, '$')
let spawn_col = match(first_spawn[0], 'r') + 1
call assert_true(spawn_col >= 7)
call assert_true(spawn_col <= 40)

call yank_and_slash#undo()
call assert_equal(4, b:ys.turn)
call assert_equal(0, strlen(substitute(join(getline(1, '$')), '[^r]', '', 'g')))
call yank_and_slash#act('yy', 1)
call assert_equal(first_spawn, getline(1, '$'))

for turn in range(6, 10)
  call yank_and_slash#act('yy', 1)
endfor
call assert_equal(10, b:ys.turn)
call assert_equal(2, strlen(substitute(join(getline(1, '$')), '[^r]', '', 'g')))

" A small edited map with no distant floor does not force a spawn.
setlocal modifiable
silent %delete _
call setline(1, ['.k>'])
setlocal nomodifiable nomodified
call cursor(1, 1)
let b:ys.turn = 4
call yank_and_slash#act('yy', 1)
call assert_equal(0, b:ys.spawned)
call assert_equal(['.k>'], getline(1, '$'))

if len(v:errors)
  for error in v:errors | echomsg error | endfor
  cquit
endif
qa!
