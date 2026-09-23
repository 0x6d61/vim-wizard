scriptencoding utf-8
set runtimepath^=.
let g:vim_wizard_seed = 42
runtime plugin/yank_and_slash.vim
let original = bufnr('%')
let tabs_before = tabpagenr('$')
VimWizard
call assert_equal(1, b:ys_menu)
call assert_equal(0, exists('b:ys'))
call assert_equal('ja', b:ys_language)
call assert_match('日本語', getline(7))
call feedkeys('j', 'xt')
call assert_equal('en', b:ys_language)
call assert_equal(0, exists('b:ys'))
call feedkeys("\<CR>", 'xt')
let game = bufnr('%')
let hud = b:ys.hud
call assert_equal(tabs_before + 1, tabpagenr('$'))
call assert_equal('vim wizard ~ yank&slash ~', getbufline(hud, 1)[0])
call assert_equal(0, getbufvar(hud, '&modifiable'))
call assert_equal(11, line('$'))
call assert_equal(39, strlen(getline(1)))
call assert_equal(12, b:ys.hp)
call assert_equal(10, b:ys.mana)
call assert_equal(1, &l:conceallevel)
call assert_equal('nvic', &l:concealcursor)
call assert_equal(0, synconcealed(1, 1)[0])
call assert_equal(char2nr('·'), char2nr(synconcealed(1, 3)[1]))
call assert_equal(char2nr('·'), char2nr(synconcealed(1, 2)[1]))
call assert_equal(0, &l:modifiable)
let menu_map = getline(1, '$')
call feedkeys('L', 'xt')
call assert_equal('ja', b:ys_language)
call assert_equal(0, b:ys.turn)
call assert_equal(menu_map, getline(1, '$'))
call assert_match('金貨', getbufline(hud, 2)[0])
call assert_match('鍵', b:ys.message)
call feedkeys('L', 'xt')
call assert_equal('en', b:ys_language)
call assert_match('GOLD', getbufline(hud, 2)[0])
call assert_match('Find k', b:ys.message)
let first_map = getline(1, '$')
call yank_and_slash#restart()
call assert_notequal(first_map, getline(1, '$'))

" Independently flood-fill generated terrain, checking both objectives.
for iteration in range(30)
  call yank_and_slash#restart()
  let board = getline(1, '$')
  let text = join(board, '')
  call assert_equal(1, strlen(substitute(text, '[^k]', '', 'g')))
  call assert_equal(1, strlen(substitute(text, '[^>]', '', 'g')))
  call assert_equal(3, strlen(substitute(text, '[^r]', '', 'g')))
  call assert_match('[#|]', text)
  call assert_equal('.', strpart(board[0], 0, 1))
  let queue = [[0, 0]]
  let seen = {'0,0': 1}
  let found = ''
  let index = 0
  while index < len(queue)
    let [row, col] = queue[index]
    let index += 1
    let found .= strpart(board[row], col, 1)
    for [nr, nc] in [[row - 1, col], [row + 1, col], [row, col - 1], [row, col + 1]]
      if nr >= 0 && nr < len(board) && nc >= 0 && nc < strlen(board[nr]) && !has_key(seen, nr.','.nc) && strpart(board[nr], nc, 1) !~# '[#|]'
        let seen[nr.','.nc] = 1
        call add(queue, [nr, nc])
      endif
    endfor
  endwhile
  call assert_match('k', found)
  call assert_match('>', found)
endfor

function! Scene(lines, row, col) abort
  setlocal modifiable
  silent %delete _
  call setline(1, a:lines)
  setlocal nomodifiable nomodified
  let b:ys.hp = 12
  let b:ys.max_hp = 12
  let b:ys.mana = 10
  let b:ys.max_mana = 10
  let b:ys.mana_steps = 0
  let b:ys.mana_spent = 0
  let b:ys.gold = 0
  let b:ys.kills = 0
  let b:ys.last_kills = 0
  let b:ys.depth = 1
  let b:ys.key = 0
  let b:ys.turn = 0
  let b:ys.done = 0
  let b:ys.history = []
  call cursor(a:row, a:col)
endfunction

" Actual mappings preserve counts and rewind the entire enemy turn.
call Scene(['. . . .', 'k . . >'], 1, 1)
call feedkeys('2w', 'xt')
call assert_equal(5, col('.'))
call assert_equal(1, b:ys.turn)
call feedkeys('u', 'xt')
call assert_equal(1, col('.'))
call assert_equal(0, b:ys.turn)
call feedkeys('f.', 'xt')
call assert_equal(3, col('.'))
call assert_equal(1, b:ys.turn)

" A rat advances once, by one character, after a complete command.
call Scene(['. . r', 'k . >'], 1, 1)
call yank_and_slash#act('yy', 1)
call assert_equal('. .r.', getline(1))
call assert_equal(12, b:ys.hp)
call yank_and_slash#undo()
call assert_equal('. . r', getline(1))
call assert_equal(0, b:ys.turn)
call yank_and_slash#act('yy', 1)
call yank_and_slash#act('yy', 1)
call yank_and_slash#act('yy', 1)
call assert_equal(11, b:ys.hp)
call assert_equal('.r...', getline(1))

" Walls prevent attacks and movement through a completely sealed barrier.
call Scene(['r....', '#####', '..k.>'], 3, 1)
call yank_and_slash#act('yy', 1)
call assert_equal('r....', getline(1))
call assert_equal(12, b:ys.hp)
" With a gap, the rat takes the longer route around the wall.
call Scene(['r....', '####.', '.....', 'k...>'], 3, 1)
call yank_and_slash#act('yy', 1)
call assert_equal('.r...', getline(1))

" Native yank/paste builds real walls, and deleting them opens a path.
call Scene(['r....', '#####', '..k.>'], 2, 1)
call feedkeys('yyp', 'xt')
call assert_equal(['r....', '#####', '#####', '..k.>'], getline(1, '$'))
call assert_equal(2, b:ys.turn)
call yank_and_slash#undo()
call assert_equal(3, line('$'))
call cursor(2, 1)
call feedkeys('dd', 'xt')
call assert_equal(['r....', '..k.>'], getline(1, '$'))
call assert_equal(11, b:ys.hp)

" Killing a rat by editing removes it from subsequent enemy updates.
call Scene(['.r.k>'], 1, 2)
call feedkeys('x', 'xt')
call assert_equal('..k>', getline(1))
call assert_equal(12, b:ys.hp)
call yank_and_slash#undo()
call assert_equal('.r.k>', getline(1))

" Pasted rats come alive; loot and exits are never overwritten by rats.
call Scene(['..k>'], 1, 1)
call setreg('"', 'r', 'v')
call yank_and_slash#act('p', 1)
call assert_equal('.r.k>', getline(1))
call assert_equal(11, b:ys.hp)
call Scene(['.k.r>'], 1, 1)
call yank_and_slash#act('yy', 1)
call assert_equal('.k.r>', getline(1))

" Empty/ragged edited boards remain valid, including deleting every row.
call Scene(['r', '', 'k >'], 3, 1)
call yank_and_slash#act('yy', 1)
call assert_equal('r', getline(1))
call cursor(1, 1)
call yank_and_slash#act('dd', 3)
call assert_equal([''], getline(1, '$'))
call yank_and_slash#undo()
call assert_equal(['r', '', '. >'], getline(1, '$'))

" Floor transitions rewind both the old board and RNG for repeatability.
call Scene(['.k>'], 1, 1)
call yank_and_slash#act('l', 1)
call assert_equal(1, b:ys.key)
let rng = b:ys.rng
call yank_and_slash#act('l', 1)
let next_map = getline(1, '$')
call assert_equal(2, b:ys.depth)
call assert_equal(4, strlen(substitute(join(next_map), '[^r]', '', 'g')))
call yank_and_slash#undo()
call assert_equal(1, b:ys.depth)
call assert_equal(1, b:ys.key)
call assert_equal(rng, b:ys.rng)
call assert_equal(['..>'], getline(1, '$'))
call yank_and_slash#act('l', 1)
call assert_equal(next_map, getline(1, '$'))

call Scene(['.k>'], 1, 1)
let b:ys.depth = 3
call yank_and_slash#act('l', 1)
call yank_and_slash#act('l', 1)
call assert_equal(0, b:ys.done)
call assert_equal(4, b:ys.depth)
call assert_equal(b:ys.max_mana, b:ys.mana)
call assert_match('Level up', b:ys.message)
call yank_and_slash#undo()
call assert_equal(0, b:ys.done)
call assert_equal(3, b:ys.depth)

" A precise slash costs less than erasing an entire row.
call Scene(['r'.repeat('.', 38), 'k.>'], 1, 1)
call yank_and_slash#act('x', 1)
call assert_equal(8, b:ys.mana)
call yank_and_slash#undo()
call assert_equal(10, b:ys.mana)
call yank_and_slash#act('dd', 1)
call assert_equal(2, b:ys.mana)
call assert_equal(8, b:ys.mana_spent)
call yank_and_slash#undo()
call assert_equal(10, b:ys.mana)

" Counted cuts cost 8 MP per command, regardless of the number of rows.
call Scene([repeat('.', 39), repeat('.', 39), 'k.>'], 1, 1)
call yank_and_slash#act('dd', 2)
call assert_equal(2, b:ys.mana)
call assert_equal(8, b:ys.mana_spent)
call yank_and_slash#undo()
let b:ys.mana = 7
call setreg('0', 'yanked', 'v')
call setreg('1', ['old cut'], 'V')
call setreg('-', 'small cut', 'v')
call setreg('"', {'points_to': '0'})
let regs = map(split('0123456789-"', '\zs'), 'getreginfo(v:val)')
let board = getline(1, '$')
let pos = getpos('.')
call yank_and_slash#act('dd', 2)
call assert_equal(board, getline(1, '$'))
call assert_equal(pos, getpos('.'))
call assert_equal(regs, map(split('0123456789-"', '\zs'), 'getreginfo(v:val)'))
call assert_equal(7, b:ys.mana)
call assert_equal(0, b:ys.turn)
call assert_equal([], b:ys.history)
call assert_match('Need 8 MP', b:ys.message)
call yank_and_slash#language('ja')
call assert_match('MPが8必要', b:ys.message)
call yank_and_slash#language('en')

" Actual movement regenerates MP; failed moves and yank do not.
call Scene(['. . . .', 'k.>'], 1, 1)
let b:ys.mana = 0
call feedkeys('hyyyyww', 'xt')
call assert_equal(0, b:ys.mana)
call assert_equal(2, b:ys.mana_steps)
call feedkeys('w', 'xt')
call assert_equal(1, b:ys.mana)
call assert_equal(0, b:ys.mana_steps)
call assert_equal([1, 7], [line('.'), col('.')])
redraw!
" Scan left-to-right like a redraw; Vim caches the last syntax query.
call assert_equal('·', synconcealed(1, 1)[1])
call assert_equal(0, synconcealed(1, 7)[0])
call yank_and_slash#undo()
call assert_equal(0, b:ys.mana)
call assert_equal(2, b:ys.mana_steps)
call yank_and_slash#act('x', 1)
call assert_equal('mana_low', b:ys.notice)
call assert_equal(0, b:ys.mana)

" Deep floors do not terminate and enemy counts remain bounded.
for depth in [9, 99, 999]
  call Scene(['.k>'], 1, 1)
  let b:ys.depth = depth
  let b:ys.mana = 0
  call yank_and_slash#act('l', 1)
  call yank_and_slash#act('l', 1)
  call assert_equal(depth + 1, b:ys.depth)
  call assert_equal(0, b:ys.done)
  call assert_equal(b:ys.max_mana, b:ys.mana)
  call assert_equal(12, strlen(substitute(join(getline(1, '$')), '[^r]', '', 'g')))
  call assert_match('FLOOR '.(depth + 1), getbufline(hud, 2)[0])
  call yank_and_slash#undo()
  call assert_equal(depth, b:ys.depth)
  call assert_equal(0, b:ys.mana)
endfor
call Scene(['.r.k>'], 1, 1)
let b:ys.hp = 1
call yank_and_slash#act('yy', 1)
call assert_equal(1, b:ys.done)
call assert_equal(0, b:ys.hp)
call yank_and_slash#undo()
call assert_equal(1, b:ys.hp)
call assert_equal(0, b:ys.done)
call assert_match('HP', getbufline(hud, 2)[0])
" The bilingual shortcut guide opens and closes without touching the run.
for language in ['en', 'ja']
  call yank_and_slash#language(language)
  let saved_state = deepcopy(b:ys)
  let saved_board = getline(1, '$')
  let saved_position = getpos('.')
  let saved_register = getreginfo('"')
  let game_tabs = tabpagenr('$')
  call feedkeys('?', 'xt')
  let guide = bufnr('%')
  call assert_notequal(game, guide)
  call assert_equal(game_tabs + 1, tabpagenr('$'))
  call assert_equal(0, &l:modifiable)
  call assert_equal(0, &l:conceallevel)
  call assert_match(language ==# 'ja' ? 'Vimの基本操作' : 'Vim shortcuts', getline(2))
  let guide_text = join(getline(1, '$'), "\n")
  for shortcut in ['h / j / k / l', '0 / ^ / $', '3w', '2dd', 'Ctrl-r', ':wq']
    call assert_true(stridx(guide_text, shortcut) >= 0, shortcut)
  endfor
  call assert_match(language ==# 'ja' ? 'ゲーム外で使う参考情報' : 'NOT game actions', guide_text)
  call feedkeys('G', 'xt')
  call assert_equal(line('$'), line('.'))
  call feedkeys("gg\<C-d>", 'xt')
  call assert_true(line('.') > 1)
  call feedkeys(language ==# 'ja' ? "\<Esc>" : 'q', 'xt')
  call assert_equal(game, bufnr('%'))
  call assert_equal(0, bufexists(guide))
  call assert_equal(game_tabs, tabpagenr('$'))
  call assert_equal(saved_state, b:ys)
  call assert_equal(saved_board, getline(1, '$'))
  call assert_equal(saved_position, getpos('.'))
  call assert_equal(saved_register, getreginfo('"'))
endfor
call yank_and_slash#close(game)
call assert_equal(0, bufexists(game))
call assert_equal(0, bufexists(hud))
call assert_equal(original, bufnr('%'))
call assert_equal(tabs_before, tabpagenr('$'))
" Language chosen on the title screen carries into help, play and undo.
YankAndSlash
call feedkeys("\<Down>\<Up>\<CR>", 'xt')
call assert_equal('ja', b:ys_language)
call assert_match('金貨', getbufline(b:ys.hud, 2)[0])
call assert_match('敵', join(yank_and_slash#i18n#get('ja', 'help')))
call assert_match('Rats', join(yank_and_slash#i18n#get('en', 'help')))
call Scene(['.k>'], 1, 1)
call yank_and_slash#act('l', 1)
call assert_match('鍵を拾った', b:ys.message)
call yank_and_slash#language()
call assert_match('Key collected', b:ys.message)
call yank_and_slash#undo()
call assert_equal('en', b:ys_language)
call assert_match('Rewound', b:ys.message)
call yank_and_slash#close(bufnr('%'))
VimWizard
let title_buffer = bufnr('%')
call feedkeys('q', 'xt')
call assert_equal(0, bufexists(title_buffer))
call assert_equal(original, bufnr('%'))
if !empty(v:errors)
  for error in v:errors
    echom error
  endfor
  cquit
endif
qa!
