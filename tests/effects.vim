scriptencoding utf-8
set runtimepath^=.
let g:vim_wizard_language = 'en'
let g:vim_wizard_seed = 42
runtime plugin/yank_and_slash.vim
VimWizard
call yank_and_slash#begin()
let game = bufnr('%')
let game_window = win_getid()

function! Scene(lines, row, col) abort
  call yank_and_slash#restart()
  setlocal modifiable
  silent %delete _
  call setline(1, a:lines)
  setlocal nomodifiable nomodified
  call cursor(a:row, a:col)
  normal! zt
  redraw!
endfunction

function! OverlayCount() abort
  if has('nvim')
    return len(filter(nvim_list_wins(), '!empty(nvim_win_get_config(v:val).relative)'))
  endif
  return len(popup_list())
endfunction

" A real multi-kill creates overlays without putting effect text in the map.
call Scene(['r.r.r..', '....k.>'], 1, 1)
call yank_and_slash#act('dd', 1)
call assert_equal(3, b:ys.kills)
call assert_equal(3, b:ys.last_kills)
call assert_equal(2, b:ys.mana)
call assert_match('3 KILLS', b:ys.message)
call assert_equal(['....k.>'], getline(1, '$'))
call assert_false(empty(get(b:, 'ys_effect', {})), get(b:, 'ys_effect_error', 'No effect created'))
call assert_true(OverlayCount() > 0)
let event = deepcopy(get(b:, 'ys_effect', {}))
let board = getline(1, '$')
let state = deepcopy(b:ys)
let register = getreginfo('"')
let position = getpos('.')
let started = reltime()
while !empty(get(b:, 'ys_effect', {})) && reltimefloat(reltime(started)) < 2
  sleep 10m
endwhile
call assert_equal({}, get(b:, 'ys_effect', {}))
call assert_equal(0, OverlayCount())
call assert_equal(state, b:ys)
call assert_equal(board, getline(1, '$'))
call assert_equal(register, getreginfo('"'))
call assert_equal(position, getpos('.'))
call assert_equal(game_window, win_getid())
call assert_equal('', get(b:, 'ys_effect_error', ''))
if has_key(event, 'timer') | call assert_equal([], timer_info(event.timer)) | endif

" An immediate next command cancels visuals and still executes normally.
call Scene(['.r..', 'k..>'], 1, 2)
call yank_and_slash#act('x', 1)
call assert_equal(1, b:ys.kills)
call assert_equal(1, b:ys.last_kills)
call assert_match('1 KILL!', b:ys.message)
call assert_true(OverlayCount() > 0)
let old_timer = get(get(b:, 'ys_effect', {}), 'timer', -1)
call yank_and_slash#act('l', 1)
call assert_equal(2, b:ys.turn)
call assert_equal(3, col('.'))
call assert_equal(1, b:ys.kills)
call assert_equal(0, OverlayCount())
call yank_and_slash#effects#tick(game, old_timer)
call assert_equal(2, b:ys.turn)

" Rejected attacks never award kills or create a slash.
call Scene(['r.r.r..', '....k.>'], 1, 1)
let b:ys.mana = 0
call yank_and_slash#act('dd', 1)
call assert_equal(0, b:ys.kills)
call assert_equal(0, b:ys.turn)
call assert_equal(0, OverlayCount())
call assert_equal('mana_low', b:ys.notice)

" Undo restores kills and cleans up an in-flight attack.
let b:ys.mana = 10
call yank_and_slash#act('dd', 1)
call assert_true(OverlayCount() > 0)
call yank_and_slash#undo()
call assert_equal(0, b:ys.kills)
call assert_equal(10, b:ys.mana)
call assert_equal(0, OverlayCount())
call assert_equal(['r.r.r..', '....k.>'], getline(1, '$'))

" Summoning a wall highlights only newly pasted building material.
call Scene(['#####', '....k.>'], 1, 1)
call yank_and_slash#act('yy', 1)
call yank_and_slash#act('p', 1)
call assert_equal(['#####', '#####', '....k.>'], getline(1, '$'))
call assert_equal('build', b:ys.notice)
call assert_equal(0, b:ys.kills)
call assert_match('WALL RAISED', b:ys.message)
call assert_false(empty(get(b:, 'ys_effect', {})), get(b:, 'ys_effect_error', 'No build effect'))
if !empty(get(b:, 'ys_effect', {}))
  call assert_equal('build', b:ys_effect.event.key)
  call assert_equal('#####', b:ys_effect.event.walls[0].text)
endif
call assert_true(OverlayCount() > 0)
call yank_and_slash#help()
call assert_equal(0, OverlayCount())
call feedkeys('q', 'xt')
call assert_equal(game, bufnr('%'))

" Disabling animation still reports the outcome in the HUD.
let g:vim_wizard_effects = 0
call Scene(['r.r.r..', '....k.>'], 1, 1)
call yank_and_slash#language('ja')
call yank_and_slash#act('dd', 1)
call assert_match('3体撃破', b:ys.message)
call assert_equal(3, b:ys.kills)
call assert_equal(0, OverlayCount())
let g:vim_wizard_effects = 1

" Restart and close cancel timers; no overlay survives the game.
call Scene(['r.r.r..', '....k.>'], 1, 1)
call yank_and_slash#act('dd', 1)
call assert_true(OverlayCount() > 0)
call yank_and_slash#restart()
call assert_equal(0, OverlayCount())
call assert_equal(0, b:ys.kills)
call Scene(['r.r.r..', '....k.>'], 1, 1)
call yank_and_slash#act('dd', 1)
let last_timer = get(get(b:, 'ys_effect', {}), 'timer', -1)
call assert_equal('', get(b:, 'ys_effect_error', ''))
call yank_and_slash#close(game)
call assert_equal(0, OverlayCount())
if last_timer >= 0 | call assert_equal([], timer_info(last_timer)) | endif
if !empty(v:errors)
  for error in v:errors | echom error | endfor
  cquit
endif
qa!
