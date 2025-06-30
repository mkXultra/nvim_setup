" claude-projects-fzf-improved.vim
" vim-fzf用のClaude Projects JSONLビューアー（改良版）

if exists('g:loaded_claude_projects_fzf')
  finish
endif
let g:loaded_claude_projects_fzf = 1

" プレビュー用の一時ファイルを作成する関数
function! s:create_preview_command() abort
  " プレビュー処理を行うPythonスクリプトを作成
  let preview_script = tempname()
  call writefile([
        \ '#!/bin/bash',
        \ 'filepath=$(echo "$1" | rev | cut -d"|" -f1 | rev | sed "s/^ //")',
        \ 'if [ -f "$filepath" ]; then',
        \ '  if command -v python3 >/dev/null 2>&1; then',
        \ '    python3 -c "',
        \ 'import json',
        \ 'import sys',
        \ 'filepath = sys.argv[1]',
        \ 'with open(filepath, \"r\") as f:',
        \ '    for line in f:',
        \ '        try:',
        \ '            data = json.loads(line)',
        \ '            if \"message\" in data and isinstance(data[\"message\"], dict):',
        \ '                msg = data[\"message\"]',
        \ '                if \"role\" in msg and \"content\" in msg:',
        \ '                    role = msg[\"role\"]',
        \ '                    content = msg[\"content\"]',
        \ '                    text_parts = []',
        \ '                    if isinstance(content, list):',
        \ '                        for item in content:',
        \ '                            if isinstance(item, dict) and \"type\" in item:',
        \ '                                if item[\"type\"] == \"text\" and \"text\" in item:',
        \ '                                    text_parts.append(item[\"text\"])',
        \ '                                elif item[\"type\"] == \"tool_use\" and \"name\" in item:',
        \ '                                    text_parts.append(\"[Tool: \" + item[\"name\"] + \"]\")',
        \ '                        content = \" \".join(text_parts)',
        \ '                    if content and content != \"[No text content]\":',
        \ '                        print(\"[\" + role + \"]\")',
        \ '                        print(content)',
        \ '                        print(\"---\")',
        \ '        except:',
        \ '            pass',
        \ '" "$filepath"',
        \ '  elif command -v jq >/dev/null 2>&1; then',
        \ '    # jqフォールバック（シンプル版）',
        \ '    jq -r ''select(.message.role and .message.content) | "[\(.message.role)]\n\(.message.content)\n---"'' "$filepath" 2>/dev/null',
        \ '  else',
        \ '    echo "Python3またはjqがインストールされていません"',
        \ '  fi',
        \ 'else',
        \ '  echo "ファイルが見つかりません"',
        \ 'fi'
        \ ], preview_script)
  call system('chmod +x ' . preview_script)
  return preview_script
endfunction

" JSONLファイルのメッセージを抽出（Vim内部処理用）
function! s:extract_messages(filepath) abort
  let messages = []
  if filereadable(a:filepath)
    for line in readfile(a:filepath)
      try
        let json = json_decode(line)
        if has_key(json, 'message') && type(json.message) == v:t_dict
          if has_key(json.message, 'role') && has_key(json.message, 'content')
            let role = json.message.role
            let content = json.message.content
            
            " contentが配列の場合、各要素を処理
            if type(content) == v:t_list
              let text_parts = []
              for item in content
                if type(item) == v:t_dict && has_key(item, 'type')
                  if item.type == 'text' && has_key(item, 'text')
                    call add(text_parts, item.text)
                  elseif item.type == 'tool_use' && has_key(item, 'name')
                    call add(text_parts, '[Tool: ' . item.name . ']')
                  endif
                endif
              endfor
              let content = join(text_parts, ' ')
              if empty(content)
                let content = '[No text content]'
              endif
            endif
            
            " [No text content]の場合はスキップ
            if content != '[No text content]'
              call add(messages, '[' . role . ']')
              call add(messages, content)
              call add(messages, '---')
            endif
          endif
        endif
      catch
        " JSON解析エラーは無視
      endtry
    endfor
  endif
  return messages
endfunction

" 相対時間を計算する関数
function! s:get_relative_time(timestamp) abort
  let now = localtime()
  let diff = now - a:timestamp
  
  if diff < 60
    return printf('%ds ago', diff)
  elseif diff < 3600
    return printf('%dm ago', diff / 60)
  elseif diff < 86400
    return printf('%dh ago', diff / 3600)
  elseif diff < 604800
    return printf('%dd ago', diff / 86400)
  elseif diff < 2592000
    return printf('%dw ago', diff / 604800)
  elseif diff < 31536000
    return printf('%dmo ago', diff / 2592000)
  else
    return printf('%dy ago', diff / 31536000)
  endif
endfunction

" JSONLファイルの行数を取得
function! s:get_line_count(filepath) abort
  let lines = readfile(a:filepath)
  return len(lines)
endfunction

" ファイル情報を取得してフォーマット
function! s:format_file_entry(filepath) abort
  let filename = fnamemodify(a:filepath, ':t')
  let mtime = getftime(a:filepath)
  let update_time = s:get_relative_time(mtime)
  let line_count = s:get_line_count(a:filepath)
  
  " より見やすい表示フォーマット - ファイル名を短縮してUUIDの一部のみ表示
  let short_name = filename
  if len(filename) > 36
    let short_name = strpart(filename, 0, 8) . '...' . strpart(filename, len(filename)-10)
  endif
  
  return printf('%-36s | %4d行 | %s', short_name, line_count, update_time)
endfunction

" JSONLファイルリストを生成
function! s:get_jsonl_files() abort
  let cwd = getcwd()
  let dirname = substitute(cwd, '/', '-', 'g')
  let dirname = substitute(dirname, '_', '-', 'g')
  let claude_dir = expand('~/.claude/projects/' . dirname)
  
  if !isdirectory(claude_dir)
    call s:show_error('ディレクトリが存在しません: ' . claude_dir)
    return []
  endif
  
  let jsonl_files = glob(claude_dir . '/*.jsonl', 0, 1)
  
  if empty(jsonl_files)
    call s:show_error('JSONLファイルが見つかりません: ' . claude_dir)
    return []
  endif
  
  " ファイル情報とパスのペアを作成
  let entries = []
  for filepath in jsonl_files
    call add(entries, {
          \ 'display': s:format_file_entry(filepath),
          \ 'path': filepath,
          \ 'mtime': getftime(filepath)
          \ })
  endfor
  
  " 更新日時で降順ソート
  call sort(entries, {a, b -> b.mtime - a.mtime})
  
  " fzf用の表示文字列リストを返す
  return map(copy(entries), {idx, val -> val.display . ' | ' . val.path})
endfunction

" エラー表示
function! s:show_error(msg) abort
  echohl ErrorMsg
  echo a:msg
  echohl None
endfunction

" 選択されたファイルを処理
function! s:handle_selection(line) abort
  if empty(a:line)
    return
  endif
  
  " fzfの選択結果から実際のファイルパスを抽出
  let parts = split(a:line, ' | ')
  if len(parts) < 2
    call s:show_error('ファイルパスの抽出に失敗しました: ' . a:line)
    return
  endif
  
  " 最後の部分がファイルパス
  let filepath = trim(parts[-1])
  
  " メッセージビューアーを開く
  call s:open_message_viewer(filepath)
endfunction

" メッセージビューアーを開く
function! s:open_message_viewer(filepath) abort
  let messages = s:extract_messages(a:filepath)
  
  if empty(messages)
    call s:show_error('メッセージが見つかりません: ' . a:filepath)
    return
  endif
  
  " 既存のClaude Messagesバッファがあれば再利用
  let existing_buf = bufnr('Claude\ Messages:')
  if existing_buf != -1
    execute 'bwipeout! ' . existing_buf
  endif
  
  " 新しいバッファを作成（垂直分割）
  vnew
  
  " バッファ設定
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal nowrap
  setlocal nonumber
  setlocal norelativenumber
  setlocal nocursorline
  
  " メッセージを設定
  call setline(1, messages)
  
  " 読み取り専用に設定
  setlocal nomodifiable
  
  " バッファ名を設定
  let bufname = 'Claude Messages: ' . fnamemodify(a:filepath, ':t')
  execute 'file ' . fnameescape(bufname)
  
  " ステータスラインをカスタマイズ
  setlocal statusline=Claude\ Messages\ \|\ %{fnamemodify(b:claude_filepath,':t')}\ \|\ Lines:\ %L
  let b:claude_filepath = a:filepath
  
  " キーマッピング
  nnoremap <buffer> <silent> q :close<CR>
  nnoremap <buffer> <silent> <Esc> :close<CR>
  nnoremap <buffer> <silent> r :call <SID>reload_messages()<CR>
  nnoremap <buffer> <silent> o :call <SID>open_raw_file('edit')<CR>
  nnoremap <buffer> <silent> y :call <SID>copy_session_id()<CR>
  
  " カラー設定
  if has('syntax')
    syntax clear
    syntax match ClaudeUser /^User:.*/
    syntax match ClaudeAssistant /^Assistant:.*/
    syntax match ClaudeSystem /^System:.*/
    
    highlight link ClaudeUser Question
    highlight link ClaudeAssistant Statement
    highlight link ClaudeSystem Comment
  endif
  
  " カーソルを先頭に移動
  normal! gg
endfunction

" メッセージをリロード
function! s:reload_messages() abort
  if exists('b:claude_filepath')
    let messages = s:extract_messages(b:claude_filepath)
    setlocal modifiable
    silent! %delete _
    call setline(1, messages)
    setlocal nomodifiable
    echo 'リロードしました'
  endif
endfunction

" 生のJSONLファイルを開く
function! s:open_raw_file(command) abort
  if exists('b:claude_filepath')
    let filepath = b:claude_filepath
    " 現在のビューアーを閉じる
    close
    " 生のファイルを開く
    execute a:command . ' ' . fnameescape(filepath)
  endif
endfunction

" セッションIDをクリップボードにコピー
function! s:copy_session_id() abort
  if exists('b:claude_filepath')
    let filename = fnamemodify(b:claude_filepath, ':t:r')  " 拡張子を除いたファイル名
    " システムのクリップボードにコピー
    if has('clipboard')
      let @+ = filename
      echo 'セッションIDをコピーしました: ' . filename
    else
      " クリップボードが使えない場合は無名レジスタにコピー
      let @" = filename
      echo 'セッションIDをレジスタにコピーしました: ' . filename
    endif
  endif
endfunction

" メインのブラウズ関数
function! claude_projects_fzf#browse() abort
  " ripgrepの存在チェック
  if !executable('rg')
    call s:show_error('ripgrep (rg) がインストールされていません。')
    echohl WarningMsg
    echo 'ripgrepをインストールしてください: https://github.com/BurntSushi/ripgrep'
    echohl None
    return
  endif
  
  let entries = s:get_jsonl_files()
  
  if empty(entries)
    return
  endif
  
  " プレビューコマンドを作成
  let preview_script = s:create_preview_command()
  
  " ディレクトリパスを生成
  let cwd = getcwd()
  let dirname = substitute(cwd, '/', '-', 'g')
  let dirname = substitute(dirname, '_', '-', 'g')
  let claude_dir = expand('~/.claude/projects/' . dirname)
  
  " ripgrep検索スクリプトを作成
  let rg_script = tempname()
  call writefile([
        \ '#!/bin/bash',
        \ 'cd ' . shellescape(claude_dir),
        \ 'if [ -z "$1" ]; then',
        \ '  # 検索クエリが空の場合は全ファイルリストを表示',
        \ '  for file in *.jsonl; do',
        \ '    if [ -f "$file" ]; then',
        \ '      lines=$(wc -l < "$file")',
        \ '      mtime=$(stat -c %Y "$file" 2>/dev/null || date +%s)',
        \ '      now=$(date +%s)',
        \ '      diff=$((now - mtime))',
        \ '      if [ $diff -lt 60 ]; then',
        \ '        ago="${diff}s ago"',
        \ '      elif [ $diff -lt 3600 ]; then',
        \ '        ago="$((diff / 60))m ago"',
        \ '      elif [ $diff -lt 86400 ]; then',
        \ '        ago="$((diff / 3600))h ago"',
        \ '      else',
        \ '        ago="$((diff / 86400))d ago"',
        \ '      fi',
        \ '      short_name="$file"',
        \ '      if [ ${#file} -gt 36 ]; then',
        \ '        short_name="${file:0:8}...${file: -10}"',
        \ '      fi',
        \ '      printf "%-36s | %4d行 | %-8s | %s/%s\n" "$short_name" "$lines" "$ago" "' . claude_dir . '" "$file"',
        \ '    fi',
        \ '  done | sort -k5 -r',
        \ 'else',
        \ '  # ripgrepで検索（JSON内のコンテンツも検索）',
        \ '  rg -l --no-heading --color=never -i "$1" *.jsonl 2>/dev/null | while read -r file; do',
        \ '    if [ -f "$file" ]; then',
        \ '      lines=$(wc -l < "$file")',
        \ '      matches=$(rg -c -i "$1" "$file" 2>/dev/null || echo 0)',
        \ '      mtime=$(stat -c %Y "$file" 2>/dev/null || date +%s)',
        \ '      now=$(date +%s)',
        \ '      diff=$((now - mtime))',
        \ '      if [ $diff -lt 60 ]; then',
        \ '        ago="${diff}s ago"',
        \ '      elif [ $diff -lt 3600 ]; then',
        \ '        ago="$((diff / 60))m ago"',
        \ '      elif [ $diff -lt 86400 ]; then',
        \ '        ago="$((diff / 3600))h ago"',
        \ '      else',
        \ '        ago="$((diff / 86400))d ago"',
        \ '      fi',
        \ '      short_name="$file"',
        \ '      if [ ${#file} -gt 36 ]; then',
        \ '        short_name="${file:0:8}...${file: -10}"',
        \ '      fi',
        \ '      printf "%-36s | %4d行 | %-8s | %3d件 | %s/%s\n" "$short_name" "$lines" "$ago" "$matches" "' . claude_dir . '" "$file"',
        \ '    fi',
        \ '  done',
        \ '  # 検索結果が0件の場合',
        \ '  if [ $(rg -l --no-heading --color=never -i "$1" *.jsonl 2>/dev/null | wc -l) -eq 0 ]; then',
        \ '    echo "検索結果: 0件"',
        \ '  fi',
        \ 'fi'
        \ ], rg_script)
  call system('chmod +x ' . rg_script)
  
  " fzfオプションを設定
  let opts = {
        \ 'source': 'bash ' . rg_script,
        \ 'sink': function('s:handle_selection'),
        \ 'options': [
        \   '--preview', 'sh ' . preview_script . ' {}',
        \   '--preview-window', 'right:50%:wrap',
        \   '--prompt', 'Claude JSONL> ',
        \   '--header', 'ディレクトリ: ' . claude_dir . ' (入力でripgrep検索)',
        \   '--bind', 'ctrl-/:toggle-preview',
        \   '--bind', 'change:reload:bash ' . rg_script . ' {q}',
        \   '--phony'
        \ ],
        \ 'window': { 'width': 0.9, 'height': 0.8 }
        \ }
  
  " スクリプトのクリーンアップを設定
  augroup ClaudeProjectsFzfCleanup
    autocmd!
    execute 'autocmd User FzfClosed silent! call delete("' . preview_script . '")'
    execute 'autocmd User FzfClosed silent! call delete("' . rg_script . '")'
  augroup END
  
  call fzf#run(fzf#wrap('claude_projects', opts))
endfunction

" コマンド定義
command! -nargs=0 ClaudeProjects call claude_projects_fzf#browse()

" オプション: キーマッピング設定関数
function! claude_projects_fzf#setup(...) abort
  let opts = a:0 > 0 ? a:1 : {}
  
  " デフォルト設定
  let g:claude_projects_fzf_keymap = get(opts, 'keymap', '')
  
  " キーマッピング設定
  if !empty(g:claude_projects_fzf_keymap)
    execute 'nnoremap <silent> ' . g:claude_projects_fzf_keymap . ' :ClaudeProjects<CR>'
  endif
endfunction

" ヘルプテキスト
function! claude_projects_fzf#help() abort
  echo "Claude Projects FZF - ヘルプ"
  echo "=========================="
  echo ""
  echo "コマンド:"
  echo "  :ClaudeProjects - JSONLファイルブラウザを開く"
  echo ""
  echo "fzf内のキー操作:"
  echo "  Enter     - ファイルを選択してメッセージビューアーを開く"
  echo "  Ctrl-/    - プレビューの表示/非表示"
  echo "  Ctrl-r    - リスト更新"
  echo "  Esc       - キャンセル"
  echo ""
  echo "メッセージビューアーのキー操作:"
  echo "  q, Esc    - ビューアーを閉じる"
  echo "  r         - メッセージをリロード"
  echo "  o         - 生のJSONLファイルを開く"
  echo "  y         - セッションIDをコピー"
endfunction