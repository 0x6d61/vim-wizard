" Transient, non-focusable overlays. Never write animation into the map.
scriptencoding utf-8

function! yank_and_slash#effects#capture(board, position, key, count) abort
  let info = getwininfo(win_getid())[0]
  let event = {'key': a:key, 'win': win_getid(), 'view': winsaveview(),
        \ 'bounds': [info.winrow, info.wincol, info.winrow + info.height - 1, info.wincol + info.width - 1],
        \ 'rows': [], 'rats': [], 'start': 0}
  let offset = 0
  for row in range(len(a:board))
    if row < a:position[1] - 1
      let event.start += strlen(a:board[row]) + 1
    endif
    if a:key ==# 'dd' && row >= a:position[1] - 1 && row < a:position[1] - 1 + a:count
      let first = screenpos(event.win, row + 1, 1)
      if first.row > 0 && first.col > 0
        call add(event.rows, [first.row, first.col, strlen(a:board[row])])
      endif
    endif
    for col in range(strlen(a:board[row]))
      if strpart(a:board[row], col, 1) ==# 'r'
        let point = screenpos(event.win, row + 1, col + 1)
        call add(event.rats, {'offset': offset + col, 'row': point.row, 'col': point.col})
      endif
    endfor
    let offset += strlen(a:board[row]) + 1
  endfor
  if a:key !=# 'dd' | let event.start += a:position[2] - 1 | endif
  return event
endfunction

function! yank_and_slash#effects#building(board, first, last) abort
  let event = yank_and_slash#effects#capture(a:board, a:first, 'build', 1)
  let event.rats = []
  let event.walls = []
  for row in range(max([1, a:first[1]]), min([len(a:board), a:last[1]]))
    let start = row == a:first[1] ? a:first[2] - 1 : 0
    let end = row == a:last[1] ? a:last[2] : strlen(a:board[row - 1])
    let text = strpart(a:board[row - 1], start, end - start)
    let at = 0
    while at < strlen(text)
      let hit = match(text, '[#|+-]\+', at)
      if hit < 0 | break | endif
      let walls = matchstr(text, '[#|+-]\+', at)
      let point = screenpos(event.win, row, start + hit + 1)
      if point.row > 0 && point.col > 0
        call add(event.walls, {'row': point.row, 'col': point.col, 'text': walls})
      endif
      let at = hit + strlen(walls)
    endwhile
  endfor
  return event
endfunction

function! s:close_windows(effect) abort
  for overlay in a:effect.windows
    if has('nvim')
      if nvim_win_is_valid(overlay.win)
        silent! call nvim_win_close(overlay.win, v:true)
      endif
      if nvim_buf_is_valid(overlay.buf)
        silent! call nvim_buf_delete(overlay.buf, {'force': v:true})
      endif
    else
      silent! call popup_close(overlay.win)
    endif
  endfor
  let a:effect.windows = []
endfunction

function! yank_and_slash#effects#stop(game) abort
  let effect = getbufvar(a:game, 'ys_effect', {})
  if empty(effect) | return | endif
  if bufexists(a:game) | call setbufvar(a:game, 'ys_effect', {}) | endif
  if effect.timer >= 0 | call timer_stop(effect.timer) | endif
  call s:close_windows(effect)
endfunction

function! s:overlay(effect, row, col, text, highlight) abort
  let bounds = a:effect.event.bounds
  if a:row < bounds[0] || a:row > bounds[2] | return | endif
  let col = max([bounds[1], a:col])
  let text = a:text
  while strdisplaywidth(text) > bounds[3] - col + 1 && !empty(text)
    let text = strcharpart(text, 0, strchars(text) - 1)
  endwhile
  if empty(text) | return | endif
  let width = strdisplaywidth(text)
  if has('nvim')
    let buffer = nvim_create_buf(v:false, v:true)
    " Track the buffer immediately so exceptions cannot leak resources.
    let overlay = {'win': -1, 'buf': buffer}
    call add(a:effect.windows, overlay)
    call nvim_buf_set_lines(buffer, 0, -1, v:true, [text])
    let overlay.win = nvim_open_win(buffer, v:false, {'relative': 'editor',
          \ 'row': a:row - 1, 'col': col - 1, 'width': width, 'height': 1,
          \ 'focusable': v:false, 'style': 'minimal', 'noautocmd': v:true, 'zindex': 60})
    call nvim_win_set_option(overlay.win, 'winhighlight', 'Normal:'.a:highlight.',NormalNC:'.a:highlight)
    call nvim_buf_set_option(buffer, 'modifiable', v:false)
  else
    let window = popup_create(text, {'line': a:row, 'col': col,
          \ 'minwidth': width, 'maxwidth': width, 'minheight': 1, 'maxheight': 1,
          \ 'wrap': 0, 'mapping': 0, 'fixed': 1, 'posinvert': 0,
          \ 'padding': [0, 0, 0, 0], 'highlight': a:highlight, 'zindex': 60})
    call add(a:effect.windows, {'win': window, 'buf': winbufnr(window)})
  endif
endfunction

function! s:draw(effect) abort
  call s:close_windows(a:effect)
  let event = a:effect.event
  let step = a:effect.step
  for wall in get(event, 'walls', [])[:11]
    call s:overlay(a:effect, wall.row, wall.col, step == 0 ? repeat('*', strlen(wall.text)) : wall.text, 'YSFxBuild')
  endfor
  if event.key ==# 'dd' && step < 3
    for [row, col, width] in event.rows[:7]
      let span = min([width, max([1, width * (step + 1) / 3])])
      call s:overlay(a:effect, row, col, repeat('-', max([0, span - 1])).'>', 'YSFxSlash')
    endfor
  endif
  for point in event.rats[:7]
    if point.row <= 0 || point.col <= 0 | continue | endif
    let spark = step == 0 ? '*' : (step < 3 ? '+*+' : '. .')
    call s:overlay(a:effect, point.row - (step >= 3 ? 1 : 0), point.col - (strlen(spark) / 2), spark, step < 3 ? 'YSFxHit' : 'YSFxFade')
  endfor
  if !empty(event.label)
    let anchor = !empty(event.rats) ? event.rats[0] : {}
    if get(anchor, 'row', 0) <= 0
      let anchor = screenpos(event.win, line('.'), col('.'))
    endif
    let row = anchor.row > event.bounds[0] ? anchor.row - 1 : anchor.row + 1
    let col = min([anchor.col, event.bounds[3] - strdisplaywidth(event.label) + 1])
    call s:overlay(a:effect, row, col, event.label, event.key ==# 'build' ? 'YSFxBuild' : (event.kills > 1 ? 'YSFxMulti' : 'YSFxHit'))
  endif
  redraw
endfunction

function! yank_and_slash#effects#tick(game, timer) abort
  let effect = getbufvar(a:game, 'ys_effect', {})
  if empty(effect) || effect.timer != a:timer | return | endif
  " Abandon old screen coordinates after tab/window changes or scrolling.
  let view = winsaveview()
  if bufnr('%') != a:game || win_getid() != effect.event.win
        \ || view.topline != effect.event.view.topline || view.leftcol != effect.event.view.leftcol
        \ || &lines != effect.lines || &columns != effect.columns
    call yank_and_slash#effects#stop(a:game)
    return
  endif
  let effect.step += 1
  if effect.step >= effect.frames
    call yank_and_slash#effects#stop(a:game)
    return
  endif
  try
    call s:draw(effect)
  catch
    call setbufvar(a:game, 'ys_effect_error', v:exception)
    call yank_and_slash#effects#stop(a:game)
  endtry
endfunction

function! yank_and_slash#effects#play(event, removed, kills, label) abort
  if !get(g:, 'vim_wizard_effects', 1) || !exists('*timer_start')
        \ || (!has('nvim') && !exists('*popup_create'))
    return
  endif
  let event = deepcopy(a:event)
  call filter(event.rats, 'v:val.offset >= event.start && v:val.offset < event.start + a:removed && v:val.row > 0 && v:val.col > 0')
  let event.kills = a:kills
  let event.label = a:label
  if event.key !=# 'build' && (a:removed <= 0 || (empty(event.rats) && empty(event.rows))) | return | endif
  if event.key ==# 'build' && empty(event.walls) | return | endif
  let game = bufnr('%')
  call yank_and_slash#effects#stop(game)
  let view = winsaveview()
  if view.topline != event.view.topline || view.leftcol != event.view.leftcol | return | endif
  highlight default YSFxSlash cterm=bold ctermfg=White ctermbg=DarkMagenta gui=bold guifg=#ffffff guibg=#7c3aed
  highlight default YSFxHit cterm=bold ctermfg=Yellow ctermbg=Black gui=bold guifg=#ffd166 guibg=#171222
  highlight default YSFxMulti cterm=bold ctermfg=Black ctermbg=Yellow gui=bold guifg=#171222 guibg=#ffd166
  highlight default YSFxFade ctermfg=DarkYellow ctermbg=Black guifg=#9b744a guibg=#171222
  highlight default YSFxBuild cterm=bold ctermfg=White ctermbg=DarkCyan gui=bold guifg=#ffffff guibg=#087f8c
  let b:ys_effect = {'event': event, 'windows': [], 'timer': -1, 'step': 0,
        \ 'frames': a:kills > 1 ? 8 : 5, 'lines': &lines, 'columns': &columns}
  try
    call s:draw(b:ys_effect)
    let b:ys_effect.timer = timer_start(50, function('yank_and_slash#effects#tick', [game]), {'repeat': -1})
  catch
    let b:ys_effect_error = v:exception
    call yank_and_slash#effects#stop(game)
  endtry
endfunction
