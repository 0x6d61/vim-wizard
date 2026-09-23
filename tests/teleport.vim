scriptencoding utf-8
set runtimepath^=.
let g:vim_wizard_seed = 42
runtime plugin/yank_and_slash.vim
VimWizard
call feedkeys("\<CR>", 'xt')

function! Scene(lines, col, mana) abort
  setlocal modifiable
  silent %delete _
  call setline(1, a:lines)
  setlocal nomodifiable nomodified
  call cursor(1, a:col)
  let b:ys.hp = 12
  let b:ys.mana = a:mana
  let b:ys.turn = 0
  let b:ys.done = 0
  let b:ys.history = []
endfunction

call Scene(['. . r', 'k.>'], 1, 1)
call feedkeys('fr', 'xt')
call assert_equal(5, col('.'))
call assert_equal(0, b:ys.mana)
call assert_equal(11, b:ys.hp)
call assert_equal(1, b:ys.turn)
call yank_and_slash#undo()
call assert_equal(1, b:ys.mana)
call assert_equal(12, b:ys.hp)

call Scene(['. . r', 'k.>'], 1, 0)
call feedkeys('tr', 'xt')
call assert_equal(4, col('.'))
call assert_equal(0, b:ys.mana)
call assert_equal(10, b:ys.hp)
call assert_match('敵が2回動く', b:ys.message)

" A failed search costs no MP and uses only the normal enemy phase.
call Scene(['. . r', 'k.>'], 1, 1)
call feedkeys('fz', 'xt')
call assert_equal(1, col('.'))
call assert_equal(1, b:ys.mana)
call assert_equal(1, b:ys.turn)

call Scene(['r . .', 'k.>'], 5, 1)
call feedkeys('Fr', 'xt')
call assert_equal(1, col('.'))
call assert_equal(0, b:ys.mana)
call Scene(['r . .', 'k.>'], 5, 0)
call feedkeys('Tr', 'xt')
call assert_equal(2, col('.'))
call assert_equal(10, b:ys.hp)

" A floor gain is repeatable after undo and always lies in 1..9.
call Scene(['.k>'], 1, 0)
let b:ys.max_hp = 12
let b:ys.max_mana = 10
call yank_and_slash#act('l', 1)
call yank_and_slash#act('l', 1)
let gains = [b:ys.hp_gain, b:ys.mana_gain]
call assert_true(gains[0] >= 1 && gains[0] <= 9)
call assert_true(gains[1] >= 1 && gains[1] <= 9)
call assert_equal(12 + gains[0], b:ys.max_hp)
call assert_equal(10 + gains[1], b:ys.max_mana)
call assert_equal(b:ys.max_mana, b:ys.mana)
call yank_and_slash#undo()
call assert_equal(12, b:ys.max_hp)
call assert_equal(10, b:ys.max_mana)
call yank_and_slash#act('l', 1)
call assert_equal(gains, [b:ys.hp_gain, b:ys.mana_gain])

if len(v:errors)
  for error in v:errors | echomsg error | endfor
  cquit
endif
qa!
