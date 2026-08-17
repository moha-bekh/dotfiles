{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    mouse = true;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    baseIndex = 1;
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      yank
      tmux-sessionx
      {
        plugin = tokyo-night-tmux;
        extraConfig = "set -g @tokyo-night-tmux_transparent 1";
      }
    ];

    extraConfig = ''
      unbind r
      bind r source-file $HOME/.config/tmux/tmux.conf \; display-message "tmux.conf reloaded"

      set-option -ga terminal-overrides ",xterm-256color:Tc"
      set-option -g renumber-windows on
      set-option -g status-position top

      bind-key y set-window-option synchronize-panes \; display-message "Sync mode toggled."

      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      bind -n M-h previous-window
      bind -n M-l next-window
      bind-key -n M-k swap-window -t -1
      bind-key -n M-j swap-window -t +1
    '';
  };
}
