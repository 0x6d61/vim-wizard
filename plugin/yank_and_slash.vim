if exists('g:loaded_yank_and_slash')
  finish
endif
let g:loaded_yank_and_slash = 1
command! YankAndSlash call yank_and_slash#start()
command! VimWizard call yank_and_slash#start()
