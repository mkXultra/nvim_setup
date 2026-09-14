" ファイル名をヤンクするキーマッピング
" ===========================================
" レジスタに設定後、TextYankPostイベントを手動で発火させる

function! s:yank_to_registers(value, message) abort
  call setreg('"', a:value)
  if has('clipboard')
    call setreg('+', a:value)
  endif
  doautocmd TextYankPost
  echo a:message . a:value
endfunction

" <leader>cf (copy filename) - ファイル名のみ
nnoremap <silent> <leader>cf :<C-U>call <SID>yank_to_registers(expand("%:t"), "Yanked filename: ")<CR>

" <leader>cp (copy path) - 相対パス
nnoremap <silent> <leader>cp :<C-U>call <SID>yank_to_registers(expand("%"), "Yanked path: ")<CR>

" <leader>cP (copy Path) - 絶対パス
nnoremap <silent> <leader>cP :<C-U>call <SID>yank_to_registers(expand("%:p"), "Yanked full path: ")<CR>
