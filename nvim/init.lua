vim.opt.number = true
-- リーダーキーの設定
vim.g.mapleader = " "

-- ターミナルを開いたら自動的にインサートモード（入力可能状態）に
vim.api.nvim_create_autocmd("TermOpen", {
	pattern = "*",
	command = "startinsert",
})

-- WSL環境かどうかを確認してから設定
if vim.fn.system("uname -r"):match("microsoft") then
	vim.api.nvim_create_augroup("Yank", { clear = true })
	vim.api.nvim_create_autocmd("TextYankPost", {
		group = "Yank",
		callback = function()
			vim.fn.system("iconv -f UTF-8 -t CP932 | clip.exe", vim.fn.getreg('"'))
		end,
	})
end

-- ========== プラグイン設定 ==========
-- lazy.nvimのインストール
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- プラグインの設定
require("lazy").setup({
	{
		"sindrets/diffview.nvim",
		dependencies = "nvim-lua/plenary.nvim",
		config = function()
			require("diffview").setup({
				-- お好みの設定をここに追加
				enhanced_diff_hl = true,
			})
		end,
	},
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		init = function()
			vim.o.timeout = true
			vim.o.timeoutlen = 300 -- キーを押してからヘルプが表示されるまでの時間（ミリ秒）
		end,
		config = function()
			local wk = require("which-key")
			wk.setup()

			wk.add({
				{ "<leader>d", group = "Diffview" },
				{ "<leader>dc", desc = "Close diffview" },
				{ "<leader>dh", desc = "File history" },
				{ "<leader>do", desc = "Open diffview" },
				{ "<leader>t", group = "Terminal" },
				{ "<leader>th", desc = "Horizontal terminal" },
				{ "<leader>tt", desc = "Horizontal terminal" },
				{ "<leader>tv", desc = "Vertical terminal" },

				{ "<leader>f", desc = "Format" },
				{ "<leader>r", group = "Rename/Refactor" },
				{ "<leader>rn", desc = "Rename" },
				{ "<leader>c", group = "Code" },
				{ "<leader>ca", desc = "Code action" },
				{ "<leader>x", group = "Diagnostics" },
				{ "<leader>xx", desc = "Toggle trouble" },
				{ "<leader>xw", desc = "Workspace diagnostics" },
				{ "<leader>xd", desc = "Document diagnostics" },
				{ "<leader>q", desc = "Diagnostic list" },
			})
		end,
	},

	-- LSP関連のプラグイン
	{
		-- LSPの基本設定
		"neovim/nvim-lspconfig",
		dependencies = {
			-- LSPのインストーラー
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",

			-- 補完エンジン
			"hrsh7th/nvim-cmp",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",

			-- スニペット
			"L3MON4D3/LuaSnip",
			"saadparwaiz1/cmp_luasnip",

			-- 補完時のアイコン
			"onsails/lspkind.nvim",
		},
		config = function()
			-- Masonのセットアップ
			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"volar", -- Vue Language Server
					"ts_ls", -- TypeScript Language Server
					"eslint", -- ESLint
					"tailwindcss", -- TailwindCSSがある場合
				},
			})

			-- 補完の設定
			local cmp = require("cmp")
			local lspkind = require("lspkind")

			cmp.setup({
				snippet = {
					expand = function(args)
						require("luasnip").lsp_expand(args.body)
					end,
				},
				mapping = cmp.mapping.preset.insert({
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					-- Tabで次の候補、Shift+Tabで前の候補
					["<Tab>"] = cmp.mapping.select_next_item(),
					["<S-Tab>"] = cmp.mapping.select_prev_item(),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
				}, {
					{ name = "buffer" },
					{ name = "path" },
				}),
				formatting = {
					format = lspkind.cmp_format({
						mode = "symbol_text",
						maxwidth = 50,
					}),
				},
			})

			-- LSPの設定
			local lspconfig = require("lspconfig")
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- キーマッピングの設定
			local on_attach = function(client, bufnr)
				local opts = { noremap = true, silent = true, buffer = bufnr }

				-- 定義にジャンプ
				vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
				-- 型定義にジャンプ
				vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, opts)
				-- 実装にジャンプ
				vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
				-- 参照を表示
				vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
				-- ホバー情報を表示
				vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
				-- シグネチャヘルプ
				vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
				-- リネーム
				vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
				-- コードアクション
				vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
				-- フォーマット
				vim.keymap.set("n", "<leader>f", function()
					vim.lsp.buf.format({ async = true })
				end, opts)

				-- 診断情報のキーマップ
				vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
				vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
				vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, opts)
			end

			-- Volar (Vue)の設定
			lspconfig.volar.setup({
				capabilities = capabilities,
				on_attach = on_attach,
				filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue", "json" },
				init_options = {
					typescript = {
						-- ts_lsのパスを指定（必要に応じて）
						-- tsdk = vim.fn.getcwd() .. "/node_modules/typescript/lib"
					},
					languageFeatures = {
						implementation = true,
						references = true,
						definition = true,
						typeDefinition = true,
						callHierarchy = true,
						hover = true,
						rename = true,
						signatureHelp = true,
						codeAction = true,
						completion = {
							defaultTagNameCase = "both",
							defaultAttrNameCase = "kebabCase",
						},
					},
				},
			})

			-- TypeScript Serverの設定
			lspconfig.ts_ls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
				root_dir = function(fname)
					return lspconfig.util.root_pattern("package.json", "tsconfig.json", ".git")(fname)
				end,
				single_file_support = false,
			})

			-- ESLintの設定
			lspconfig.eslint.setup({
				capabilities = capabilities,
				on_attach = function(client, bufnr)
					on_attach(client, bufnr)
					-- 保存時に自動修正
					vim.api.nvim_create_autocmd("BufWritePre", {
						buffer = bufnr,
						command = "EslintFixAll",
					})
				end,
			})

			-- TailwindCSSの設定（使用している場合）
			lspconfig.tailwindcss.setup({
				capabilities = capabilities,
				on_attach = on_attach,
			})

			-- 診断表示の設定
			vim.diagnostic.config({
				virtual_text = {
					prefix = "●",
				},
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
			})

			-- 診断のサインを定義
			local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
			end
		end,
	},

	-- エラー表示を見やすくするプラグイン
	{
		"folke/trouble.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("trouble").setup()
			-- エラー一覧を表示
			vim.keymap.set("n", "<leader>xx", "<cmd>TroubleToggle<cr>")
			vim.keymap.set("n", "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>")
			vim.keymap.set("n", "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>")
		end,
	},

	-- インラインでエラーを見やすく表示
	{
		"https://git.sr.ht/~whynothugo/lsp_lines.nvim",
		config = function()
			require("lsp_lines").setup()
			-- デフォルトでは無効化（トグルで切り替え）
			vim.diagnostic.config({ virtual_lines = false })
			-- トグルキー
			vim.keymap.set("n", "<leader>l", function()
				local config = vim.diagnostic.config()
				vim.diagnostic.config({ virtual_lines = not config.virtual_lines })
			end, { desc = "Toggle lsp_lines" })
		end,
	},
	-- fzf.vim
	{
		"junegunn/fzf",
		build = "./install --all",
	},
	{
		"junegunn/fzf.vim",
		dependencies = { "junegunn/fzf" },
		config = function()
			-- Rgコマンドのカスタマイズ
			vim.api.nvim_create_user_command("Rg", function(opts)
				local cmd = "rg --column --line-number --no-heading --color=always --smart-case -- "
					.. vim.fn.shellescape(opts.args)
				vim.fn["fzf#vim#grep"](cmd, 1, vim.fn["fzf#vim#with_preview"](), opts.bang)
			end, { nargs = "*", bang = true })

			-- fzfのレイアウト設定（オプション）
			vim.g.fzf_layout = { down = "~40%" }

			-- プレビューウィンドウの設定
			vim.g.fzf_preview_window = { "right:50%", "ctrl-/" }
		end,
	},

	-- ファイルのインデントを自動検出
	{ "tpope/vim-sleuth" },

	-- インデントライン
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		opts = {},
		config = function()
			require("ibl").setup({
				-- インデントライン
				indent = {
					char = "│", -- インデントラインの文字
					-- char = "▏", -- より細いライン
					-- char = "┊", -- 点線風
				},
				-- 現在のスコープをハイライト
				scope = {
					enabled = true,
					show_start = true,
					show_end = false,
					highlight = "IblScope",
				},
				-- 空行でもインデントラインを表示
				whitespace = {
					remove_blankline_trail = false,
				},
				-- 除外するファイルタイプ
				exclude = {
					filetypes = {
						"help",
						"terminal",
						"lazy",
						"lspinfo",
						"TelescopePrompt",
						"TelescopeResults",
						"mason",
						"",
					},
				},
			})
		end,
	},

	-- Gitの変更をサイドバーに表示
	{
		"lewis6991/gitsigns.nvim",
		config = function()
			require("gitsigns").setup({
				-- Gitの変更をサイドバーに表示
				signs = {
					add = { text = "│" },
					change = { text = "│" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
					untracked = { text = "┆" },
				},
			})
		end,
	},
})

-- ========== キーマッピング ==========

-- diffview用のキーマッピング（オプション）
vim.keymap.set("n", "<Leader>do", ":DiffviewOpen<CR>", { desc = "Open DiffView" })
vim.keymap.set("n", "<Leader>dc", ":DiffviewClose<CR>", { desc = "Close DiffView" })
vim.keymap.set("n", "<Leader>dh", ":DiffviewFileHistory<CR>", { desc = "File History" })

vim.keymap.set("n", "<leader>fg", ":Rg<CR>", { desc = "Grep files" })
vim.keymap.set("n", "<leader>ff", ":Files<CR>", { desc = "Find files" })
vim.keymap.set("n", "<leader>fb", ":Buffers<CR>", { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fh", ":History<CR>", { desc = "File history" })

-- インサートモードでjjをESCに
vim.keymap.set("i", "jj", "<ESC>")
-- ターミナルモードでjjをターミナルノーマルモードへ
vim.keymap.set("t", "jj", "<C-\\><C-n>")

-- ========== ターミナル分割のキーマッピング ==========
vim.keymap.set("n", "<Leader>th", ":belowright split<CR>:terminal<CR>")
vim.keymap.set("n", "<Leader>tt", ":belowright split<CR>:terminal<CR>")
vim.keymap.set("n", "<Leader>tv", ":belowright vsplit<CR>:terminal<CR>")

-- Gitsignsからブランチ情報を取得
function get_git_info()
    local git_info = vim.b.gitsigns_status_dict
    if git_info and git_info.head then
        return " " .. git_info.head
    end
    return ""
end

function get_mode_icon()
    local mode = vim.api.nvim_get_mode().mode
    local mode_map = {
        n = " NORMAL",
        i = " INSERT",
        v = " VISUAL",
        V = " V-LINE",
        c = " COMMAND",
        R = " REPLACE",
    }
    return mode_map[mode] or mode
end

-- ステータスライン（アイコン付き）
vim.o.statusline = table.concat({
    '%{v:lua.get_mode_icon()}',                              -- モード
    ' | ',
    ' %f',                                                    -- ファイル名
    '%{v:lua.get_git_info()}',                              -- Gitブランチ
    ' %m%r%h',
    '%=',
    ' %{&filetype}',                                         -- ファイルタイプ
    ' | %{&expandtab?"Spaces":"Tabs"}%{&expandtab?&shiftwidth:&tabstop}',
    ' |  %l:%c',
    ' | %p%% ',
})
