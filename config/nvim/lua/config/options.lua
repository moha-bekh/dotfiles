-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- LazyVim only ships "en" spell files; add "fr" so French markdown/text/gitcommit
-- files aren't flagged word-for-word (spellcheck accepts a word valid in either language)
vim.opt.spelllang = { "en", "fr" }
