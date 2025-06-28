# Neovim Setup

個人用のNeovim設定を管理するリポジトリです。複数のPCで同じ設定を共有できます。

## セットアップ

### 1. Neovimのインストール
```bash
./install.sh
```

### 2. 設定ファイルのリンク
```bash
./install_config.sh
```

## ディレクトリ構成

```
nvim_setup/
├── install.sh          # Neovimインストールスクリプト
├── install_config.sh   # 設定シンボリックリンク作成スクリプト
├── nvim/              # Neovim設定ファイル
└── README.md
```

## 使い方

1. このリポジトリをクローン
2. `nvim/`ディレクトリに設定ファイル（init.lua等）を配置
3. 各PCで`install_config.sh`を実行してシンボリックリンクを作成
4. リポジトリを更新すれば全PCに自動反映