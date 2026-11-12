#!/usr/bin/env bash
# Claude Code status line: what's left of the 5h and weekly limits (and when
# they reset), plus the context window in use. Claude Code pipes the session
# JSON on stdin; linked to ~/.claude/statusline.sh by scripts/link.sh.
#
#   5h 60% left (reset 16:18) · weekly 80% left (reset Mon 01:38) · ctx 20K/200K tokens
input=$(cat)

f=$(jq -r '.rate_limits.five_hour.used_percentage // empty | 100 - . | round' <<<"$input")
w=$(jq -r '.rate_limits.seven_day.used_percentage // empty | 100 - . | round' <<<"$input")

# reset time: epoch seconds or ISO date -> local time in the given format
rt() {
  local v
  v=$(jq -r "$1 // empty" <<<"$input")
  [ -z "$v" ] && return
  case "$v" in
  *[!0-9.]*) date -d "$v" +"$2" 2>/dev/null ;; # ISO date (GNU date only)
  *) date -d "@${v%.*}" +"$2" 2>/dev/null || date -r "${v%.*}" +"$2" 2>/dev/null ;; # GNU || BSD/macOS
  esac
}
r5=$(rt .rate_limits.five_hour.resets_at %H:%M)
r7=$(rt .rate_limits.seven_day.resets_at "%a %H:%M")

c=$(jq -r '
  def k: if . >= 1000 then (. / 1000 | round | tostring) + "K" else (round | tostring) end;
  .context_window as $c | ($c.context_window_size // null) as $s
  | (if $c.current_usage then
       ($c.current_usage.input_tokens // 0) + ($c.current_usage.cache_creation_input_tokens // 0) + ($c.current_usage.cache_read_input_tokens // 0)
     elif ($c.used_percentage and $s) then $c.used_percentage * $s / 100
     else null end) as $u
  | if $u == null then empty elif $s then ($u | k) + "/" + ($s | k) else ($u | k) end
' <<<"$input")

out=""
add() { [ -n "$out" ] && out="$out · "; out="$out$1"; }
[ -n "$f" ] && add "5h ${f}% left${r5:+ (reset ${r5})}"
[ -n "$w" ] && add "weekly ${w}% left${r7:+ (reset ${r7})}"
[ -n "$c" ] && add "ctx ${c} tokens"
printf "%s" "$out"
