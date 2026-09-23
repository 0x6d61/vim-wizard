scriptencoding utf-8
let s:title = 'vim wizard ~ yank&slash ~'

function! s:t(key, ...) abort
  return call('yank_and_slash#i18n#get', [b:ys_language, a:key] + a:000)
endfunction

function! yank_and_slash#quit_enter() abort
  return getcmdtype() ==# ':' && getcmdline() ==# 'q' ? "\<C-U>qa\<CR>" : "\<CR>"
endfunction

function! s:new_state(hud) abort
  let seed = get(g:, 'vim_wizard_seed', float2nr(reltimefloat(reltime()) * 1000))
  return {'hp': 12, 'max_hp': 12, 'mana': 10, 'max_mana': 10,
        \ 'hp_gain': 0, 'mana_gain': 0, 'mana_steps': 0, 'mana_spent': 0,
        \ 'required_mana': 0, 'gold': 0, 'kills': 0, 'last_kills': 0, 'depth': 1, 'key': 0, 'turn': 0,
        \ 'scrolls': 0, 'stock': {'hp': 1, 'mana': 1, 'scroll': 1}, 'scroll_used': 0,
        \ 'done': 0, 'history': [], 'hud': a:hud,
        \ 'rng': abs(seed) % 2147483646 + 1,
        \ 'notice': 'intro', 'damage': 0, 'missing': 0, 'spawned': 0, 'message': ''}
endfunction

function! s:random(limit) abort
  let b:ys.rng = (b:ys.rng * 48271) % 2147483647
  return b:ys.rng % a:limit
endfunction

function! s:cell(board, row, col) abort
  if a:row < 0 || a:row >= len(a:board) || a:col < 0 || a:col >= strlen(a:board[a:row])
    return '#'
  endif
  return strpart(a:board[a:row], a:col, 1)
endfunction

function! s:put(board, row, col, tile) abort
  let text = a:board[a:row]
  let a:board[a:row] = strpart(text, 0, a:col).a:tile.strpart(text, a:col + 1)
endfunction

function! s:neighbors(row, col) abort
  return [[a:row - 1, a:col], [a:row, a:col - 1], [a:row + 1, a:col], [a:row, a:col + 1]]
endfunction

" Breadth-first distances over the actual text, including ragged edited rows.
function! s:distances(board, row, col, loot_blocks) abort
  let queue = [[a:row, a:col]]
  let distances = {a:row.','.a:col: 0}
  let index = 0
  while index < len(queue)
    let [row, col] = queue[index]
    let index += 1
    for [nr, nc] in s:neighbors(row, col)
      let id = nr.','.nc
      let tile = s:cell(a:board, nr, nc)
      if has_key(distances, id) || tile !~# '^[. rk$>]$' || (a:loot_blocks && tile =~# '[k$>]')
        continue
      endif
      let distances[id] = distances[row.','.col] + 1
      call add(queue, [nr, nc])
    endfor
  endwhile
  return distances
endfunction

function! s:carve(board, start, end) abort
  let [row, col] = a:start
  while 1
    call s:put(a:board, row, col, col % 2 ? ' ' : '.')
    if [row, col] == a:end | break | endif
    if col == a:end[1] || (row != a:end[0] && s:random(2))
      let row += row < a:end[0] ? 1 : -1
    else
      let col += col < a:end[1] ? 1 : -1
    endif
  endwhile
endfunction

function! s:generate() abort
  let board = repeat([repeat('. ', 19).'.'], 11)
  " Short editable fences, not a rigid outer border.
  for fence in range(12)
    let row = 1 + s:random(8)
    let col = 2 + 2 * s:random(14)
    if s:random(2)
      for offset in range(3 + 2 * s:random(3))
        call s:put(board, row, col + offset, '#')
      endfor
    else
      for offset in range(2 + s:random(2))
        call s:put(board, row + offset, col, '|')
      endfor
    endif
  endfor
  let key = [6 + s:random(4), 4 + 2 * s:random(8)]
  let door = [7 + s:random(4), 34 + 2 * s:random(3)]
  call s:carve(board, [0, 0], key)
  call s:carve(board, key, door)
  let reachable = s:distances(board, 0, 0, 0)
  let candidates = []
  for row in range(len(board))
    for col in range(0, strlen(board[row]) - 1, 2)
      if s:cell(board, row, col) ==# '.' && get(reachable, row.','.col, -1) >= 9 && [row, col] != key && [row, col] != door
        call add(candidates, [row, col])
      endif
    endfor
  endfor
  for tile in split(repeat('r', min([12, 2 + b:ys.depth])).'$$$', '\zs')
    if empty(candidates) | break | endif
    let [row, col] = remove(candidates, s:random(len(candidates)))
    call s:put(board, row, col, tile)
  endfor
  call s:put(board, key[0], key[1], 'k')
  call s:put(board, door[0], door[1], '>')
  return board
endfunction

function! yank_and_slash#start() abort
  tabnew
  setlocal buftype=nofile bufhidden=wipe noswapfile nowrap
  setlocal nonumber norelativenumber nolist nospell nofoldenable
  setlocal signcolumn=no foldcolumn=0 cursorline
  setlocal statusline=vim\ wizard\ ~\ yank&slash\ ~
  let b:ys_language = get(g:, 'vim_wizard_language', 'ja') ==# 'en' ? 'en' : 'ja'
  let b:ys_menu = 1
  nnoremap <silent><buffer> j :call yank_and_slash#language()<CR>
  nnoremap <silent><buffer> k :call yank_and_slash#language()<CR>
  nnoremap <silent><buffer> <Down> :call yank_and_slash#language()<CR>
  nnoremap <silent><buffer> <Up> :call yank_and_slash#language()<CR>
  nnoremap <silent><buffer> 1 :call yank_and_slash#language('ja')<CR>
  nnoremap <silent><buffer> 2 :call yank_and_slash#language('en')<CR>
  nnoremap <silent><buffer> <CR> :call yank_and_slash#begin()<CR>
  nnoremap <silent><buffer> q :bwipeout!<CR>
  cnoremap <buffer><expr> <CR> yank_and_slash#quit_enter()
  syntax match YSTitle /vim wizard\|\~ yank&slash \~/
  syntax match YSSelection /^  >.*/
  highlight default link YSTitle Title
  highlight default link YSSelection Search
  call s:menu()
endfunction

function! s:menu() abort
  call s:write(['', '  vim wizard', '  ~ yank&slash ~', '',
        \ '  Language / 言語', '',
        \ (b:ys_language ==# 'ja' ? '  > ' : '    ').'1. 日本語',
        \ (b:ys_language ==# 'en' ? '  > ' : '    ').'2. English', '',
        \ '  j/k or Up/Down : Select / 選択',
        \ '  Enter : Start / ゲーム開始',
        \ '  q : Quit / 終了', '',
        \ '  Yank walls. Slash rats. Descend forever.',
        \ '  壁をコピーし、敵を倒して地下深くへ。'])
  call cursor(b:ys_language ==# 'ja' ? 7 : 8, 3)
endfunction

function! yank_and_slash#language(...) abort
  let b:ys_language = a:0 ? a:1 : (b:ys_language ==# 'ja' ? 'en' : 'ja')
  if get(b:, 'ys_menu', 0)
    call s:menu()
  else
    call yank_and_slash#effects#stop(bufnr('%'))
    call s:show()
  endif
endfunction

function! yank_and_slash#begin() abort
  if !get(b:, 'ys_menu', 0) | return | endif
  let b:ys_menu = 0
  mapclear <buffer>
  syntax clear
  setlocal virtualedit= cursorline nomodifiable scrolloff=2
  setlocal conceallevel=1 concealcursor=nvic
  let game = bufnr('%')
  aboveleft 6new
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nolist nospell nowrap winfixheight
  setlocal nocursorline signcolumn=no foldcolumn=0
  setlocal statusline=vim\ wizard\ ~\ yank&slash\ ~
  syntax match YSTitle /^vim wizard.*/
  highlight default link YSTitle Title
  let hud = bufnr('%')
  let b:ys_game = game
  nnoremap <silent><buffer> q :call yank_and_slash#close(b:ys_game)<CR>
  cnoremap <buffer><expr> <CR> yank_and_slash#quit_enter()
  wincmd p
  let b:ys = s:new_state(hud)
  augroup vim_wizard_effects
    autocmd! * <buffer>
    autocmd BufLeave,WinLeave,BufWipeout <buffer> call yank_and_slash#effects#stop(str2nr(expand('<abuf>')))
  augroup END
  for key in ['h', 'j', 'k', 'l', 'w', 'b', 'e', '0', '^', '$', 'gg', 'G', 'x', 'dw', 'dd', 'yy', 'p', 'P', ';', ',']
    execute 'nnoremap <silent><buffer> '.key.' :<C-U>call yank_and_slash#act('.string(key).', v:count1)<CR>'
  endfor
  for key in ['f', 'F', 't', 'T']
    execute 'nnoremap <silent><buffer> '.key.' :<C-U>call yank_and_slash#find('.string(key).', v:count1)<CR>'
  endfor
  nnoremap <silent><buffer> u :call yank_and_slash#undo()<CR>
  nnoremap <silent><buffer> ? :call yank_and_slash#help()<CR>
  nnoremap <silent><buffer> S :call yank_and_slash#shop()<CR>
  nnoremap <silent><buffer> R :call yank_and_slash#restart()<CR>
  nnoremap <silent><buffer> L :call yank_and_slash#language()<CR>
  nnoremap <silent><buffer> q :call yank_and_slash#close(bufnr('%'))<CR>
  cnoremap <buffer><expr> <CR> yank_and_slash#quit_enter()
  setlocal statusline=%!yank_and_slash#status()
  syntax match YSMonster /r/
  syntax match YSTreasure /[$k]/
  syntax match YSExit />/
  syntax match YSWall /[#|+-]/
  " One visible floor tile per character, retaining native word boundaries.
  syntax match YSFloor /[. ]/ conceal cchar=·
  highlight default YSMonster cterm=bold ctermfg=Red gui=bold guifg=#ff6b6b
  highlight default YSTreasure cterm=bold ctermfg=Yellow gui=bold guifg=#ffd166
  highlight default YSExit cterm=bold ctermfg=Green gui=bold guifg=#70e5a1
  highlight default YSWall cterm=bold ctermfg=Cyan gui=bold guifg=#67c4dd
  highlight default YSFloor ctermfg=DarkGray guifg=#626875
  highlight default YSHero cterm=bold,reverse ctermfg=Magenta gui=bold,reverse guifg=#e69bff
  " Give concealed floors their own color without changing other windows.
  if exists('+winhighlight')
    setlocal winhighlight=Conceal:YSFloor
  endif
  call s:room()
endfunction

function! s:write(lines) abort
  setlocal modifiable
  silent %delete _
  call setline(1, empty(a:lines) ? ['.'] : a:lines)
  setlocal nomodifiable nomodified
endfunction

function! s:room() abort
  call yank_and_slash#effects#stop(bufnr('%'))
  call s:write(s:generate())
  let b:ys.key = 0
  let b:ys.stock = {'hp': 1, 'mana': 1, 'scroll': 1}
  call cursor(1, 1)
  " Reset the menu's remembered screen column before vertical motions.
  normal! 0zt
  call s:show()
endfunction

function! s:show() abort
  " Leave the cursor cell unconcealed so the wizard highlight stays visible.
  syntax clear YSFloor
  execute 'syntax match YSFloor /\%(\%'.line('.').'l\%'.col('.').'c\)\@![. ]/ conceal cchar=·'
  syntax sync fromstart
  let b:ys.message = b:ys.notice ==# 'mana_low' ? s:t('mana_low', b:ys.required_mana)
        \ : b:ys.notice ==# 'floor' ? s:t('floor', b:ys.hp_gain, b:ys.mana_gain) : s:t(b:ys.notice)
  if b:ys.last_kills
    let label = s:t(b:ys.last_kills == 1 ? 'kill' : 'multi_kill', b:ys.last_kills)
    let b:ys.message = label.(b:ys.notice ==# 'move' ? '' : ' '.b:ys.message)
  endif
  if b:ys.mana_spent | let b:ys.message .= s:t('spent', b:ys.mana_spent) | endif
  if b:ys.damage && b:ys.notice !=# 'dead'
    let b:ys.message .= s:t('hit', b:ys.damage)
  endif
  if b:ys.missing | let b:ys.message .= s:t('missing') | endif
  if b:ys.spawned | let b:ys.message .= s:t('spawned') | endif
  if exists('w:ys_hero') | silent! call matchdelete(w:ys_hero) | endif
  let w:ys_hero = matchaddpos('YSHero', [[line('.'), col('.'), 1]], 20)
  if bufexists(b:ys.hud)
    let info = [s:title,
          \ s:t('stats', b:ys.hp, b:ys.max_hp, b:ys.mana, b:ys.max_mana, b:ys.gold, b:ys.kills, b:ys.depth, s:t(b:ys.key ? 'yes' : 'no'), b:ys.turn, b:ys.scrolls),
          \ s:t('legend'), s:t('controls'),
          \ b:ys.message,
          \ s:t('hint')]
    call setbufvar(b:ys.hud, '&modifiable', 1)
    call setbufline(b:ys.hud, 1, info)
    call setbufvar(b:ys.hud, '&modifiable', 0)
    call setbufvar(b:ys.hud, '&modified', 0)
  endif
  redrawstatus
  let message = b:ys.message
  while strdisplaywidth(message) > &columns - 2 && !empty(message)
    let message = strcharpart(message, 0, strchars(message) - 1)
  endwhile
  echo message
endfunction

function! yank_and_slash#status() abort
  if !exists('b:ys') | return '' | endif
  return s:title.s:t('status', b:ys.hp, b:ys.mana, b:ys.depth, b:ys.turn)
endfunction

function! yank_and_slash#find(key, count) abort
  call yank_and_slash#effects#stop(bufnr('%'))
  let target = getchar()
  if type(target) != type(0) || target < 32 || target > 126
    return
  endif
  call yank_and_slash#act(a:key.nr2char(target), a:count)
endfunction

function! s:enemies() abort
  let board = getline(1, '$')
  let hero = [line('.') - 1, col('.') - 1]
  let distances = s:distances(board, hero[0], hero[1], 1)
  let rats = []
  for row in range(len(board))
    for col in range(strlen(board[row]))
      if s:cell(board, row, col) ==# 'r'
        call add(rats, [row, col])
      endif
    endfor
  endfor
  let damage = 0
  for [row, col] in rats
    let distance = get(distances, row.','.col, -1)
    if distance > 1
      for [nr, nc] in s:neighbors(row, col)
        if s:cell(board, nr, nc) =~# '^[. ]$' && get(distances, nr.','.nc, -1) == distance - 1 && [nr, nc] != hero
          call s:put(board, row, col, '.')
          call s:put(board, nr, nc, 'r')
          let [row, col] = [nr, nc]
          break
        endif
      endfor
    endif
    if abs(row - hero[0]) + abs(col - hero[1]) <= 1 && s:cell(board, hero[0], hero[1]) !~# '[#|+-]'
      let damage += 1
    endif
  endfor
  setlocal modifiable
  call setline(1, board)
  setlocal nomodifiable nomodified
  return damage
endfunction

" Add one reachable rat away from the wizard after the existing rats move.
function! s:spawn_enemy() abort
  let board = getline(1, '$')
  let rat_count = strlen(substitute(join(board, ''), '[^r]', '', 'g'))
  if rat_count >= 24 | return 0 | endif
  let distances = s:distances(board, line('.') - 1, col('.') - 1, 0)
  let candidates = []
  for row in range(len(board))
    for col in range(strlen(board[row]))
      if s:cell(board, row, col) =~# '^[. ]$' && get(distances, row.','.col, -1) >= 6
        call add(candidates, [row, col])
      endif
    endfor
  endfor
  if empty(candidates) | return 0 | endif
  let [row, col] = candidates[s:random(len(candidates))]
  call s:put(board, row, col, 'r')
  setlocal modifiable
  call setline(1, board)
  setlocal nomodifiable nomodified
  return 1
endfunction

function! s:registers() abort
  let registers = {}
  for name in split('0123456789-"', '\zs')
    let registers[name] = getreginfo(name)
  endfor
  return registers
endfunction

function! s:slash_cost(before, after) abort
  let before = join(a:before, "\n")
  let after = join(a:after, "\n")
  let removed = strlen(before) - strlen(after)
  if removed <= 0 | return 0 | endif
  let rats = strlen(substitute(before, '[^r]', '', 'g')) - strlen(substitute(after, '[^r]', '', 'g'))
  let walls = strlen(substitute(before, '[^#|+-]', '', 'g')) - strlen(substitute(after, '[^#|+-]', '', 'g'))
  return (removed + 7) / 8 + rats + (walls + 3) / 4
endfunction

function! yank_and_slash#act(key, count) abort
  call yank_and_slash#effects#stop(bufnr('%'))
  if b:ys.done
    let b:ys.notice = 'finished'
    call s:show()
    return
  endif
  let state = copy(b:ys)
  let state.stock = copy(b:ys.stock)
  call remove(state, 'history')
  let before = getline(1, '$')
  let position = getpos('.')
  let event = index(['x', 'dw', 'dd'], a:key) >= 0
        \ ? yank_and_slash#effects#capture(before, position, a:key, min([99, a:count])) : {}
  call add(b:ys.history, {'state': state, 'lines': before, 'pos': position, 'registers': s:registers()})
  let b:ys.turn += 1
  let b:ys.notice = 'move'
  let b:ys.damage = 0
  let b:ys.missing = 0
  let b:ys.spawned = 0
  let b:ys.mana_spent = 0
  let b:ys.last_kills = 0
  let b:ys.scroll_used = 0
  setlocal modifiable
  try
    execute 'normal! '.(a:count > 1 ? min([a:count, 99]) : '').a:key
  catch
    let failure = v:exception
    call yank_and_slash#undo()
    let b:ys.last_error = failure
    let b:ys.notice = 'error'
    call s:show()
    return
  finally
    setlocal nomodifiable nomodified
  endtry
  " Keep accidental huge pastes from overwhelming the scratch buffer.
  if line('$') > 100 || max(map(getline(1, '$'), 'strlen(v:val)')) > 500
    call yank_and_slash#undo()
    let b:ys.notice = 'large'
    call s:show()
    return
  endif
  if index(['x', 'dw', 'dd'], a:key) >= 0
    let after = getline(1, '$')
    let cost = a:key ==# 'dd' ? (before ==# after ? 0 : 8) : s:slash_cost(before, after)
    if cost > b:ys.mana && !(cost > 0 && b:ys.scrolls > 0)
      call yank_and_slash#undo()
      let b:ys.notice = 'mana_low'
      let b:ys.required_mana = cost
      call s:show()
      return
    endif
    if cost > 0 && b:ys.scrolls > 0
      let b:ys.scrolls -= 1
      let b:ys.scroll_used = 1
      let b:ys.notice = 'scroll_used'
    else
      let b:ys.mana -= cost
      let b:ys.mana_spent = cost
    endif
    let b:ys.last_kills = strlen(substitute(join(before), '[^r]', '', 'g')) - strlen(substitute(join(getline(1, '$')), '[^r]', '', 'g'))
    let b:ys.kills += b:ys.last_kills
  elseif a:key =~# '^[fFtT].$' && getpos('.')[1:2] != position[1:2]
    if b:ys.mana > 0
      let b:ys.mana -= 1
      let b:ys.mana_spent = 1
    else
      let b:ys.notice = 'exhausted_jump'
    endif
  elseif index(['yy', 'p', 'P'], a:key) < 0 && getpos('.')[1:2] != position[1:2]
    let b:ys.mana_steps += 1
    if b:ys.mana_steps >= 3
      let b:ys.mana = min([b:ys.max_mana, b:ys.mana + 1])
      let b:ys.mana_steps = 0
    endif
  endif
  if index(['p', 'P'], a:key) >= 0
        \ && strlen(substitute(join(getline(1, '$')), '[^#|+-]', '', 'g')) > strlen(substitute(join(before), '[^#|+-]', '', 'g'))
    let event = yank_and_slash#effects#building(getline(1, '$'), getpos("'["), getpos("']"))
    let b:ys.notice = 'build'
  endif
  if len(b:ys.history) > 100 | call remove(b:ys.history, 0) | endif
  let removed = strlen(join(before, "\n")) - strlen(join(getline(1, '$'), "\n"))
  let tile = strpart(getline('.'), col('.') - 1, 1)
  if tile ==# 'k' || tile ==# '$'
    if tile ==# 'k'
      let b:ys.key = 1
      let b:ys.notice = 'key'
    else
      let b:ys.gold += 1
      let b:ys.notice = 'gold'
    endif
    setlocal modifiable
    let text = getline('.')
    call setline('.', strpart(text, 0, col('.') - 1).'.'.strpart(text, col('.')))
    setlocal nomodifiable nomodified
  elseif tile ==# '>' && b:ys.key
    let b:ys.depth += 1
    let b:ys.turn = 0
    let b:ys.hp_gain = 1 + s:random(9)
    let b:ys.mana_gain = 1 + s:random(9)
    let b:ys.max_hp += b:ys.hp_gain
    let b:ys.max_mana += b:ys.mana_gain
    let b:ys.hp = min([b:ys.max_hp, b:ys.hp + 3 + b:ys.hp_gain])
    let b:ys.mana = b:ys.max_mana
    let b:ys.mana_steps = 0
    let b:ys.notice = 'floor'
    call s:room()
    return
  elseif tile ==# '>'
    let b:ys.notice = 'locked'
  endif
  let damage = s:enemies()
  if b:ys.notice ==# 'exhausted_jump'
    let damage += s:enemies()
  endif
  let b:ys.hp -= damage
  let b:ys.damage = damage
  if b:ys.hp <= 0
    let b:ys.hp = 0
    let b:ys.done = 1
    let b:ys.notice = 'dead'
  endif
  if !b:ys.done && b:ys.turn % 5 == 0
    let b:ys.spawned = s:spawn_enemy()
  endif
  if join(getline(1, '$')) !~# '>' || (!b:ys.key && join(getline(1, '$')) !~# 'k')
    let b:ys.missing = 1
  endif
  call s:show()
  if !empty(event)
    let label = event.key ==# 'build' ? s:t('build') : (b:ys.last_kills ? s:t(b:ys.last_kills == 1 ? 'kill' : 'multi_kill', b:ys.last_kills) : '')
    call yank_and_slash#effects#play(event, removed, b:ys.last_kills, label)
  endif
endfunction

function! yank_and_slash#undo() abort
  call yank_and_slash#effects#stop(bufnr('%'))
  if empty(b:ys.history) | return | endif
  let snap = remove(b:ys.history, -1)
  let history = b:ys.history
  let b:ys = snap.state
  let b:ys.history = history
  call s:write(snap.lines)
  call setpos('.', snap.pos)
  for name in split('0123456789-', '\zs')
    call setreg(name, snap.registers[name])
  endfor
  call setreg('"', snap.registers['"'])
  let b:ys.notice = 'rewind'
  let b:ys.damage = 0
  let b:ys.missing = 0
  let b:ys.spawned = 0
  let b:ys.mana_spent = 0
  let b:ys.last_kills = 0
  let b:ys.scroll_used = 0
  call s:show()
endfunction

function! yank_and_slash#restart() abort
  call yank_and_slash#effects#stop(bufnr('%'))
  let previous_rng = b:ys.rng
  let b:ys = s:new_state(b:ys.hud)
  " Restart continues the random stream, so R never reuses a seeded layout.
  let b:ys.rng = previous_rng
  call s:room()
endfunction

function! yank_and_slash#close(game) abort
  call yank_and_slash#effects#stop(a:game)
  let state = getbufvar(a:game, 'ys', {})
  if bufexists(get(state, 'hud', -1))
    execute 'silent! bwipeout! '.state.hud
  endif
  if bufexists(a:game)
    execute 'silent! bwipeout! '.a:game
  endif
endfunction

function! s:shop_render() abort
  let state = getbufvar(b:ys_shop_game, 'ys', {})
  if empty(state) | return | endif
  let lines = [s:title, s:t('shop_title', state.depth),
        \ s:t('shop_wallet', state.gold, state.hp, state.max_hp, state.mana, state.max_mana, state.scrolls), '',
        \ s:t('shop_item_hp', state.stock.hp),
        \ s:t('shop_item_mana', state.stock.mana),
        \ s:t('shop_item_scroll', state.stock.scroll), '',
        \ s:t('shop_navigation'), '', get(b:, 'ys_shop_message', '')]
  call s:write(lines)
  call cursor(1, 1)
endfunction

function! yank_and_slash#shop() abort
  if !exists('b:ys') || b:ys.done | return | endif
  call yank_and_slash#effects#stop(bufnr('%'))
  let game = bufnr('%')
  let language = b:ys_language
  tabnew
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nolist nospell nofoldenable
  setlocal wrap linebreak conceallevel=0 signcolumn=no foldcolumn=0 nocursorline
  let b:ys_shop_game = game
  let b:ys_language = language
  let b:ys_shop_message = ''
  nnoremap <silent><buffer> 1 :call yank_and_slash#buy('hp')<CR>
  nnoremap <silent><buffer> 2 :call yank_and_slash#buy('mana')<CR>
  nnoremap <silent><buffer> 3 :call yank_and_slash#buy('scroll')<CR>
  nnoremap <silent><buffer> q :call yank_and_slash#shop_close()<CR>
  nnoremap <silent><buffer> <Esc> :call yank_and_slash#shop_close()<CR>
  cnoremap <buffer><expr> <CR> yank_and_slash#quit_enter()
  syntax match YSTitle /^vim wizard.*/
  highlight default link YSTitle Title
  call s:shop_render()
endfunction

function! yank_and_slash#buy(item) abort
  if !exists('b:ys_shop_game') | return | endif
  let state = getbufvar(b:ys_shop_game, 'ys', {})
  if empty(state) | return | endif
  let price = a:item ==# 'scroll' ? 5 : 3
  if state.stock[a:item] <= 0
    let b:ys_shop_message = s:t('shop_sold_out')
  elseif state.gold < price
    let b:ys_shop_message = s:t('shop_no_gold')
  elseif a:item ==# 'hp' && state.hp >= state.max_hp || a:item ==# 'mana' && state.mana >= state.max_mana
    let b:ys_shop_message = s:t('shop_full')
  else
    let state.gold -= price
    let state.stock = copy(state.stock)
    let state.stock[a:item] -= 1
    if a:item ==# 'hp'
      let state.hp = min([state.max_hp, state.hp + 4])
    elseif a:item ==# 'mana'
      let state.mana = min([state.max_mana, state.mana + 5])
    else
      let state.scrolls += 1
    endif
    let b:ys_shop_message = s:t('shop_bought')
    call setbufvar(b:ys_shop_game, 'ys', state)
  endif
  call s:shop_render()
endfunction

function! yank_and_slash#shop_close() abort
  if !exists('b:ys_shop_game') | return | endif
  let game = b:ys_shop_game
  bwipeout!
  if bufnr('%') == game
    call s:show()
  endif
endfunction

function! yank_and_slash#help() abort
  call yank_and_slash#effects#stop(bufnr('%'))
  let title = s:t('help_title')
  let navigation = s:t('help_navigation')
  let contents = [s:title, title, navigation, ''] + s:t('help')
  tabnew
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nolist nospell nofoldenable
  setlocal wrap linebreak conceallevel=0 signcolumn=no foldcolumn=0
  setlocal nocursorline
  let &l:statusline = navigation
  call s:write(contents)
  call cursor(1, 1)
  syntax match YSHelpHeading /^\[.\+\]$/
  syntax match YSHelpKey /^  \S\+\%( \/ \S\+\)*/
  highlight default link YSHelpHeading Title
  highlight default link YSHelpKey Special
  nnoremap <silent><buffer> q :bwipeout!<CR>
  nnoremap <silent><buffer> <Esc> :bwipeout!<CR>
  nnoremap <silent><buffer> ? :bwipeout!<CR>
  cnoremap <buffer><expr> <CR> yank_and_slash#quit_enter()
endfunction
