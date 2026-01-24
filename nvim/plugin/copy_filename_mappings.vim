" ファイル名をヤンクするキーマッピング
" ===========================================
" レジスタに設定後、TextYankPostイベントを手動で発火させる

" <leader>cf (copy filename) - ファイル名のみ
nnoremap <leader>cf :let @"=expand("%:t")<CR>:doautocmd TextYankPost<CR>:echo "Yanked filename: " . expand("%:t")<CR>

" <leader>cp (copy path) - 相対パス
nnoremap <leader>cp :let @"=expand("%")<CR>:doautocmd TextYankPost<CR>:echo "Yanked path: " . expand("%")<CR>

" <leader>cP (copy Path) - 絶対パス
nnoremap <leader>cP :let @"=expand("%:p")<CR>:doautocmd TextYankPost<CR>:echo "Yanked full path: " . expand("%:p")<CR>