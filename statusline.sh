#!/bin/bash
TRACK_FILE="/tmp/claude-active-agents-${USER}.json"
input=$(cat)

# Extract all fields in one jq call
eval "$(echo "$input" | jq -r '
  @sh "model=\(.model.display_name // "")",
  @sh "used_pct=\(.context_window.used_percentage // "")",
  @sh "cost=\(.cost.total_cost_usd // "")",
  @sh "session_id=\(.session_id // "")",
  @sh "five_h=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "five_h_reset=\(.rate_limits.five_hour.resets_at // "")",
  @sh "seven_d=\(.rate_limits.seven_day.used_percentage // "")",
  @sh "seven_d_reset=\(.rate_limits.seven_day.resets_at // "")"
' 2>/dev/null)"

# Effort level (not in statusline JSON — read from settings.json)
effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

# Shorten model name
case "$model" in
  *Opus*4.7*1[Mm]*) model="Opus 4.7 (1M)" ;;
  *Opus*4.7*)       model="Opus 4.7" ;;
  *Opus*4.6*1[Mm]*) model="Opus 4.6 (1M)" ;;
  *Opus*4.6*)       model="Opus 4.6" ;;
  *Sonnet*4.6*1[Mm]*) model="Sonnet 4.6 (1M)" ;;
  *Sonnet*4.6*)       model="Sonnet 4.6" ;;
  *Haiku*4.5*)      model="Haiku 4.5" ;;
esac

# Context color (aggressive thresholds — never want to exceed 20%)
# green 0-9, yellow 10-13, orange 14-16, red 17+
color_for_ctx() {
  local pct=$1
  if [ "$pct" -ge 17 ] 2>/dev/null; then printf '\033[91m'
  elif [ "$pct" -ge 14 ] 2>/dev/null; then printf '\033[38;5;208m'
  elif [ "$pct" -ge 10 ] 2>/dev/null; then printf '\033[33m'
  else printf '\033[32m'; fi
}

# Rate limit color (pace-based: usage% vs elapsed%)
# delta = usage% - elapsed%, colors on how far ahead of pace
# green <= 10, yellow 11-20, orange 21-35, red 35+
color_for_pace() {
  local delta=$1
  if [ "$delta" -ge 35 ] 2>/dev/null; then printf '\033[91m'
  elif [ "$delta" -ge 21 ] 2>/dev/null; then printf '\033[38;5;208m'
  elif [ "$delta" -ge 11 ] 2>/dev/null; then printf '\033[33m'
  else printf '\033[32m'; fi
}

RST='\033[0m'
now_epoch=$(date +%s)

# Hours until reset (epoch seconds, rounded to nearest hour)
hours_until() {
  local epoch=$1
  [ -z "$epoch" ] || [ "$epoch" = "null" ] && return
  local diff=$(( epoch - now_epoch ))
  [ "$diff" -lt 0 ] && diff=0
  printf "%s" "$(( (diff + 1800) / 3600 ))h"
}

# Calculate pace delta: usage% - elapsed% of window
pace_delta() {
  local usage=$1 reset_epoch=$2 window_secs=$3
  local elapsed=$(( now_epoch - (reset_epoch - window_secs) ))
  [ "$elapsed" -lt 0 ] && elapsed=0
  [ "$elapsed" -gt "$window_secs" ] && elapsed=$window_secs
  printf "%s" "$(( usage - (elapsed * 100 / window_secs) ))"
}

# Build rate limit display for a window
# Args: label usage_pct reset_epoch window_seconds
rate_limit_display() {
  local label=$1 usage=$2 reset_epoch=$3 window_secs=$4
  local usage_int=$(printf '%.0f' "$usage")
  if [ -n "$reset_epoch" ] && [ "$reset_epoch" != "null" ]; then
    local delta=$(pace_delta "$usage_int" "$reset_epoch" "$window_secs")
    local color=$(color_for_pace "$delta")
    local remaining=$(hours_until "$reset_epoch")
    printf "%s" "${color}${label}:${usage_int}%${RST}"
    if [ -n "$remaining" ] && [ "$delta" -ge 11 ] 2>/dev/null; then
      printf "%s" "\033[90m -${remaining}${RST}"
    fi
  else
    printf "%s" "\033[32m${label}:${usage_int}%${RST}"
  fi
}

# Context
if [ -n "$used_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")
  ctx_display="\033[1m$(color_for_ctx "$used_int")CTX:${used_int}%${RST}"
else
  ctx_display="\033[1mCTX:${RST}"
fi

# Rate limits
if [ -n "$five_h" ]; then
  limit_5h=$(rate_limit_display "5h" "$five_h" "$five_h_reset" 18000)
else
  limit_5h="5h:"
fi
if [ -n "$seven_d" ]; then
  limit_7d=$(rate_limit_display "7d" "$seven_d" "$seven_d_reset" 604800)
else
  limit_7d="7d:"
fi

# Assemble: logo | ctx | 5h | 7d | model | price
parts="\033[38;2;163;189;168m<𝕊>${RST}"
parts="$parts | $ctx_display"
parts="$parts | $limit_5h"
parts="$parts | $limit_7d"
parts="$parts | \033[90m${model:-}${RST}"
[ -n "$effort" ] && parts="$parts | \033[90mE:${effort}${RST}"
parts="$parts | \033[90m\$$([ -n "$cost" ] && printf '%.2f' "$cost")${RST}"

# Active agents
if [ -f "$TRACK_FILE" ]; then
  agent_info=$(jq -r --arg sid "$session_id" '
    [to_entries[] | select(.value.session == $sid or ($sid == "")) | .value.type] |
    if length > 0 then "\(length):\(join(", "))" else empty end
  ' "$TRACK_FILE" 2>/dev/null)
  [ -n "$agent_info" ] && parts="$parts | agents(${agent_info%%:*}): ${agent_info#*:}"
fi

printf "%b" "$parts"
