-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- LazyVim enables spellcheck by default for text/markdown/gitcommit filetypes.
-- Keep the wrap behavior but turn spell off by default; toggle anytime with <leader>us.
-- Same filetypes are prose, not code, so diagnostics just clutter reading; turn
-- them off by default too, toggle anytime with <leader>ud.
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("prose_filetypes", { clear = true }),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function(ev)
    vim.opt_local.wrap = true
    vim.diagnostic.enable(false, { bufnr = ev.buf })
  end,
})
