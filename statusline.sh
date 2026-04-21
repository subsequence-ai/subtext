#!/bin/bash
TRACK_FILE="/tmp/claude-active-agents-${USER}.json"
input=$(cat)

# Extract all fields in one jq call
eval "$(echo "$input" | jq -r '
  @sh "model=\(.model.display_name // "")",
  @sh "transcript_path=\(.transcript_path // "")",
  @sh "cost=\(.cost.total_cost_usd // "")",
  @sh "session_id=\(.session_id // "")",
  @sh "cwd=\(.workspace.current_dir // "")",
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

# Token color (absolute thresholds — tied to context degradation, not window size)
# green <90k, yellow 90-129k, orange 130-159k, red 160k+
color_for_tokens() {
  local t=$1
  if [ "$t" -ge 160000 ] 2>/dev/null; then printf '\033[91m'
  elif [ "$t" -ge 130000 ] 2>/dev/null; then printf '\033[38;5;208m'
  elif [ "$t" -ge 90000 ] 2>/dev/null; then printf '\033[33m'
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

# Token usage (from transcript — the statusline JSON's used_percentage is unreliable)
tokens=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  tokens=$(tail -c 200000 "$transcript_path" 2>/dev/null \
    | grep '"type":"assistant"' | tail -1 \
    | jq -r '.message.usage as $u |
        if $u then (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0)) | tostring
        else empty end' 2>/dev/null)
fi

if [ -n "$tokens" ] && [ "$tokens" -gt 0 ] 2>/dev/null; then
  if [ "$tokens" -ge 1000000 ]; then
    tenths=$(( tokens / 100000 ))
    token_label="$(( tenths / 10 )).$(( tenths % 10 ))M"
  elif [ "$tokens" -ge 1000 ]; then
    token_label="$(( tokens / 1000 ))k"
  else
    token_label="$tokens"
  fi
  token_display="\033[1m$(color_for_tokens "$tokens")Tokens:${token_label}${RST}"
else
  token_display="\033[1mTokens:${RST}"
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

# Assemble line 1: logo | tokens | 5h | 7d | model | effort
parts="\033[38;2;163;189;168m<𝕊>${RST}"
parts="$parts | $token_display"
parts="$parts | $limit_5h"
parts="$parts | $limit_7d"
parts="$parts | \033[90m${model:-}${RST}"
[ -n "$effort" ] && parts="$parts | \033[90mE:${effort}${RST}"

# Active agents
if [ -f "$TRACK_FILE" ]; then
  agent_info=$(jq -r --arg sid "$session_id" '
    [to_entries[] | select(.value.session == $sid) | .value.type] |
    if length > 0 then "\(length):\(join(", "))" else empty end
  ' "$TRACK_FILE" 2>/dev/null)
  [ -n "$agent_info" ] && parts="$parts | agents(${agent_info%%:*}): ${agent_info#*:}"
fi

# ── Second line: branch | timer | price | task ───────────────────────────────
line2_segments=()

# Git branch (+ dirty indicator)
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    dirty=""
    [ -n "$(git -C "$cwd" status --porcelain --untracked-files=no 2>/dev/null)" ] && dirty="*"
    line2_segments+=("\033[90m${branch}${dirty}${RST}")
  fi
fi

# Session timer (duration since session transcript was created)
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  birth=$(stat -f %B "$transcript_path" 2>/dev/null)
  if [ -n "$birth" ] && [ "$birth" -gt 0 ] 2>/dev/null; then
    elapsed=$(( now_epoch - birth ))
    [ "$elapsed" -lt 0 ] && elapsed=0
    if [ "$elapsed" -lt 3600 ]; then
      timer="$(( elapsed / 60 ))m"
    else
      timer="$(( elapsed / 3600 ))h$(( (elapsed % 3600) / 60 ))m"
    fi
    line2_segments+=("\033[90m${timer}${RST}")
  fi
fi

# Price
line2_segments+=("\033[90m\$$([ -n "$cost" ] && printf '%.2f' "$cost")${RST}")

# Task (completed / total) from tasks.md in cwd
if [ -n "$cwd" ] && [ -f "$cwd/tasks.md" ]; then
  done_count=$(grep -cE '^[[:space:]]*-[[:space:]]+\[[xX]\]' "$cwd/tasks.md" 2>/dev/null)
  todo_count=$(grep -cE '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' "$cwd/tasks.md" 2>/dev/null)
  total=$(( done_count + todo_count ))
  if [ "$total" -gt 0 ]; then
    line2_segments+=("\033[90mTask:${done_count}/${total}${RST}")
  fi
fi

# Emit line 2, indented with Braille Pattern Blank (U+2800). These render
# as whitespace but are not classified as spaces, so they survive the
# status line's leading-whitespace trim.
brblank=$'\xe2\xa0\x80'
indent="${brblank}${brblank}${brblank}${brblank}"
inner=""
for seg in "${line2_segments[@]}"; do
  [ -n "$inner" ] && inner="$inner | "
  inner="$inner$seg"
done
parts="$parts\n${indent}| $inner"

printf "%b" "$parts"
