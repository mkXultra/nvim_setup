#!/bin/bash

# Neovim設定のシンボリックリンクを作成するスクリプト

# カラー定義
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NVIM_CONFIG_DIR="$SCRIPT_DIR/nvim"
TARGET_DIR="$HOME/.config/nvim"

echo "Setting up Neovim configuration..."

# .configディレクトリがなければ作成
if [ ! -d "$HOME/.config" ]; then
    mkdir -p "$HOME/.config"
    echo -e "${GREEN}Created ~/.config directory${NC}"
fi

# 既存のnvim設定をバックアップ
if [ -e "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
    BACKUP_DIR="$TARGET_DIR.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$TARGET_DIR" "$BACKUP_DIR"
    echo -e "${GREEN}Backed up existing config to: $BACKUP_DIR${NC}"
fi

# 既存のシンボリックリンクを削除
if [ -L "$TARGET_DIR" ]; then
    rm "$TARGET_DIR"
    echo "Removed existing symlink"
fi

# シンボリックリンクを作成
ln -s "$NVIM_CONFIG_DIR" "$TARGET_DIR"

if [ -L "$TARGET_DIR" ]; then
    echo -e "${GREEN}Successfully created symlink:${NC}"
    echo "  $TARGET_DIR -> $NVIM_CONFIG_DIR"
else
    echo -e "${RED}Failed to create symlink${NC}"
    exit 1
fi

echo -e "\n${GREEN}Neovim configuration setup completed!${NC}"
echo "You can now use 'nvim' with your synced configuration."