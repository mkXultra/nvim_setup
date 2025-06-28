
#!/bin/bash

# Neovimのインストールスクリプト
echo "Installing Neovim..."

# AppImageのダウンロード
curl -L -o nvim https://github.com/neovim/neovim/releases/download/v0.11.2/nvim-linux-x86_64.appimage

# 実行権限を付与
chmod u+x nvim

# /usr/local/binに移動（sudoが必要な場合があります）
sudo mv nvim /usr/local/bin/nvim

echo "Neovim installation completed!"
