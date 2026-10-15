#!/usr/bin/env bash
# macOS settings that would otherwise be clicked through System Settings.
# Safe to re-run: `defaults write` just overwrites the value.
#
#   ~/dotfiles/scripts/macos/settings.sh
#
# To find the key behind a setting: `defaults read > before.txt`, change it in
# System Settings, `defaults read > after.txt`, diff (same with -currentHost).
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Dock tile for an app, in the format persistent-apps expects.
dock_app() {
  printf '<dict><key>tile-data</key><dict><key>file-data</key><dict>'
  printf '<key>_CFURLString</key><string>%s</string>' "$1"
  printf '<key>_CFURLStringType</key><integer>0</integer>'
  printf '</dict></dict></dict>'
}

# --- appearance --------------------------------------------------------------

log "appearance: dark mode"
defaults write NSGlobalDomain AppleInterfaceStyle -string Dark

# --- dock --------------------------------------------------------------------

log "dock: auto-hide with no delay, magnification, no recents, pinned apps"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.4
defaults write com.apple.dock tilesize -int 41
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 53
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock show-process-indicators -bool false
defaults write com.apple.dock persistent-apps -array \
  "$(dock_app /Applications/Ghostty.app)" \
  "$(dock_app /Applications/Firefox.app)"
defaults write com.apple.dock persistent-others -array

# --- mission control / desktop -------------------------------------------------
# mru-spaces off: AeroSpace needs spaces to keep their order.

log "mission control: fixed spaces order, group windows by app"
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock expose-group-apps -bool true

log "desktop: no click-to-show-desktop, no widgets, no tiled window margins"
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
defaults write com.apple.WindowManager StandardHideWidgets -bool true
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

# --- keyboard ----------------------------------------------------------------

log "keyboard: fast key repeat, no autocorrect / auto-capitalize / double-space period"
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled -bool false

# Disabled system shortcuts:
#   15-26  accessibility zoom / invert colors / contrast
#   60-61  switch input source (ctrl-space, ctrl-opt-space: free for tmux & co)
#   164    (disabled in System Settings > Keyboard Shortcuts)
log "keyboard: disabling system shortcuts"
for id in 15 16 17 18 19 20 21 22 23 24 25 26; do
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" '{ enabled = 0; }'
done
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
  '{ enabled = 0; value = { parameters = (32, 49, 262144); type = standard; }; }'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
  '{ enabled = 0; value = { parameters = (32, 49, 786432); type = standard; }; }'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 164 \
  '{ enabled = 0; value = { parameters = (65535, 65535, 0); type = standard; }; }'

# --- menu bar ----------------------------------------------------------------

log "menu bar: battery percentage, hide Spotlight icon"
defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
defaults -currentHost write com.apple.controlcenter Spotlight -int 8

# --- accessibility -----------------------------------------------------------
# Writing this domain needs Full Disk Access for the terminal.

log "accessibility: reduce motion"
defaults write com.apple.universalaccess reduceMotion -bool true ||
  warn "could not set reduce motion — give the terminal Full Disk Access, or set it in System Settings > Accessibility > Display"

# --- apply -------------------------------------------------------------------

/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
killall Dock ControlCenter 2>/dev/null || true

log "done. Some settings (key repeat, shortcuts) only apply after logging out and back in."
