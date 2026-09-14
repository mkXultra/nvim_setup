#!/bin/bash
set -euo pipefail

# Neovimのインストールスクリプト
echo "Installing Neovim..."

# OSとアーキテクチャを検出
NVIM_OS=$(uname -s)
NVIM_ARCH=$(uname -m)
NVIM_VERSION="v0.11.2"

# 作業ディレクトリ内の設定やファイルに触れず、一時ファイルを終了時に削除する
NVIM_TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/nvim-install.XXXXXX")
trap 'rm -rf "$NVIM_TMP_DIR"' EXIT

if [[ "$NVIM_OS" == "Darwin" ]]; then
    if command -v brew &> /dev/null; then
        echo "Homebrew found. Installing Neovim via brew..."
        brew install neovim
    else
        echo "Homebrew not found. Installing from GitHub releases..."
        case "$NVIM_ARCH" in
            arm64|x86_64)
                NVIM_PACKAGE="nvim-macos-$NVIM_ARCH"
                ;;
            *)
                echo "Unsupported macOS architecture: $NVIM_ARCH" >&2
                exit 1
                ;;
        esac
        NVIM_URL="https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/$NVIM_PACKAGE.tar.gz"

        curl -fL -o "$NVIM_TMP_DIR/nvim.tar.gz" "$NVIM_URL"
        tar -xzf "$NVIM_TMP_DIR/nvim.tar.gz" -C "$NVIM_TMP_DIR"

        # 実行ファイルとともにlib・share内のruntimeファイルも配置する
        sudo mkdir -p /usr/local
        sudo cp -R "$NVIM_TMP_DIR/$NVIM_PACKAGE/." /usr/local/
    fi
elif [[ "$NVIM_OS" == "Linux" ]]; then
    # Linuxの場合はAppImageを使用
    curl -fL -o "$NVIM_TMP_DIR/nvim" "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux-x86_64.appimage"
    chmod u+x "$NVIM_TMP_DIR/nvim"
    sudo mkdir -p /usr/local/bin
    sudo mv "$NVIM_TMP_DIR/nvim" /usr/local/bin/nvim
else
    echo "Unsupported OS: $NVIM_OS" >&2
    exit 1
fi

echo "Neovim installation completed!"
