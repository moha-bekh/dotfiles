-- Take the language servers from Nix instead of mason.nvim.
--
-- `mason = false` is LazyVim's per-server escape hatch (see the `sopts.mason ~=
-- false` check in lazyvim/plugins/lsp/init.lua): the server is still set up,
-- but it is not added to mason's ensure_installed, so nvim-lspconfig launches
-- the binary from $PATH — which home/home.nix puts there on every host.
--
-- Why bother, when mason mostly works:
--   * mason ships no aarch64-linux clangd. On an ARM VM it fails outright with
--     "The current platform is unsupported.", so C/C++ has no LSP at all.
--   * mason's downloads are prebuilt binaries linked against /lib64/ld-linux,
--     which does not exist on NixOS — they can't even exec there.
--   * where mason does succeed it installs a *second* copy of a server Nix
--     already provides, and shadows it by prepending its own bin dir to $PATH.
--     That's how the same config ends up on different server versions per
--     machine, which is the whole thing this repo exists to avoid.
--
-- rust_analyzer is deliberately absent: LazyVim's lang.rust extra disables the
-- nvim-lspconfig server and lets rustaceanvim drive rust-analyzer, which finds
-- it on $PATH by itself. Servers not listed here (lua_ls, marksman,
-- terraform-ls, the ansible/docker ones) still come from mason.
return {
  -- mason defaults to PATH = "prepend", which puts ~/.local/share/nvim/mason/bin
  -- ahead of everything inside nvim. `mason = false` above stops *new* installs
  -- but does nothing about servers mason already downloaded on this machine, so
  -- those stale copies would keep shadowing the Nix ones. "append" flips the
  -- precedence for good — no per-machine `:MasonUninstall` needed — while the
  -- servers that only come from mason still resolve from that directory.
  {
    "mason-org/mason.nvim",
    opts = { PATH = "append" },
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = { mason = false },
        gopls = { mason = false },
        zls = { mason = false },
        vtsls = { mason = false },
        nil_ls = { mason = false },
      },
    },
  },
}
