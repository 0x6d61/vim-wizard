scriptencoding utf-8
set runtimepath^=.
let g:vim_wizard_seed = 42
runtime plugin/yank_and_slash.vim
VimWizard
call feedkeys("\<CR>", 'xt')
let game = bufnr('%')

let b:ys.gold = 15
let b:ys.hp = 5
let b:ys.mana = 2
call feedkeys('S', 'xt')
call assert_notequal(game, bufnr('%'))
call assert_match('店', getline(2))
call feedkeys('1', 'xt')
call assert_equal(9, getbufvar(game, 'ys').hp)
call assert_equal(12, getbufvar(game, 'ys').gold)
call assert_equal(0, getbufvar(game, 'ys').stock.hp)
call feedkeys('1', 'xt')
call assert_equal(12, getbufvar(game, 'ys').gold)
call feedkeys('2', 'xt')
call assert_equal(7, getbufvar(game, 'ys').mana)
call feedkeys('3', 'xt')
call assert_equal(4, getbufvar(game, 'ys').gold)
call assert_equal(1, getbufvar(game, 'ys').scrolls)
call feedkeys('q', 'xt')
call assert_equal(game, bufnr('%'))
call assert_equal(0, b:ys.turn)

" The next non-empty slash consumes the scroll even with no MP.
setlocal modifiable
silent %delete _
call setline(1, ['.k>'])
setlocal nomodifiable nomodified
call cursor(1, 1)
let b:ys.mana = 0
call yank_and_slash#act('x', 1)
call assert_equal(0, b:ys.scrolls)
call assert_equal(0, b:ys.mana)
call assert_equal(1, b:ys.turn)
call yank_and_slash#undo()
call assert_equal(1, b:ys.scrolls)
call assert_equal(0, b:ys.turn)

" A bought-out shop refreshes only when descending; turns restart at zero.
let b:ys.key = 1
call cursor(1, 3)
call yank_and_slash#act('l', 1)
call assert_equal(2, b:ys.depth)
call assert_equal(0, b:ys.turn)
call assert_equal({'hp': 1, 'mana': 1, 'scroll': 1}, b:ys.stock)
call assert_equal(1, b:ys.scrolls)
call feedkeys('S', 'xt')
call assert_match('在庫1', getline(5))
call feedkeys("\<Esc>", 'xt')
call assert_equal(game, bufnr('%'))
call yank_and_slash#undo()
call assert_equal(1, b:ys.depth)
call assert_equal(0, b:ys.stock.hp)
call assert_equal(0, b:ys.turn)
call yank_and_slash#language('en')
call feedkeys('S', 'xt')
call assert_match('SHOP', getline(2))
call feedkeys('q', 'xt')
call assert_equal(game, bufnr('%'))

if len(v:errors)
  for error in v:errors | echomsg error | endfor
  cquit
endif
qa!
