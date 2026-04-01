#!/bin/bash

# Claude Usage Fetcher — runs with a real TTY via script command

CACHE_FILE="/tmp/claude-usage-cache.json"
SESSION_FILE="/tmp/claude-usage-session.txt"
CLAUDE_BIN="/Users/ichigo/.local/bin/claude"
LOCK_FILE="/tmp/claude-usage-fetch.lock"

# Run from OMS dir (already trusted)
cd /Users/ichigo/Documents/repo/oms

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
  lock_age=$(( $(date +%s) - $(stat -f%m "$LOCK_FILE") ))
  if [ "$lock_age" -lt 60 ]; then
    exit 0
  fi
fi
echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Fetch usage via script + piped commands
{
  sleep 12
  printf "/usage\r"
  sleep 8
  printf "\033"
  sleep 2
  printf "/exit\r"
  sleep 2
} | script -q "$SESSION_FILE" "$CLAUDE_BIN" --no-chrome --disallowedTools "Bash,Edit,Write,Read,Grep,Glob,Agent" 2>/dev/null

# Strip ANSI codes
clean=$(perl -pe 's/\e\[[^a-zA-Z]*[a-zA-Z]//g; s/\e\][^\a]*(\a|\e\\)//g; s/\e\([A-Z]//g; s/[\x00-\x08\x0b\x0c\x0e-\x1f]//g' "$SESSION_FILE" 2>/dev/null)

# Parse percentages
pct_output=$(echo "$clean" | grep -oE '[0-9]+%[[:space:]]*used' | sed 's/% *used//' | head -3)
session_pct=$(echo "$pct_output" | sed -n '1p')
week_all_pct=$(echo "$pct_output" | sed -n '2p')
week_sonnet_pct=$(echo "$pct_output" | sed -n '3p')

# Parse reset times and convert to remaining time
# Session: "5pm" today -> hours remaining
# Week: "Apr 3 at 10am" -> days remaining
now_epoch=$(date +%s)
today=$(date +%Y-%m-%d)

# Extract raw reset strings
resets=$(echo "$clean" | perl -ne 'while (/Rese\w*?\s*((?:[A-Z][a-z]+\s*\d+\s*(?:at\s*)?)?\d+(?::\d+)?[ap]m)/g) { print "$1\n" }' | head -3)
session_raw=$(echo "$resets" | sed -n '1p')
week_all_raw=$(echo "$resets" | sed -n '2p')
week_sonnet_raw=$(echo "$resets" | sed -n '3p')

calc_remaining() {
  local raw="$1"
  # Check if it has a date: "Apr3at10am" or "Apr 3 at 10am"
  local month=$(echo "$raw" | perl -ne 'print $1 if /([A-Z][a-z]+)\s*\d+/')
  local day=$(echo "$raw" | perl -ne 'print $1 if /[A-Z][a-z]+\s*(\d+)/')
  local time=$(echo "$raw" | grep -oE '[0-9]+(:[0-9]+)?[ap]m')

  if [ -n "$month" ] && [ -n "$day" ]; then
    # Future date — calc days remaining
    local target=$(date -j -f "%b %d %Y %H%M" "$month $day $(date +%Y) 0000" +%s 2>/dev/null)
    local today_midnight=$(date -j -f "%Y%m%d %H%M" "$(date +%Y%m%d) 0000" +%s 2>/dev/null)
    if [ -n "$target" ] && [ -n "$today_midnight" ]; then
      local days=$(( (target - today_midnight) / 86400 ))
      if [ "$days" -le 0 ]; then
        echo "today"
      else
        echo "${days}d"
      fi
    else
      echo "$time"
    fi
  elif [ -n "$time" ]; then
    # Same day reset — show time
    echo "$time"
  else
    echo "?"
  fi
}

session_reset=$(calc_remaining "$session_raw")
week_all_reset=$(calc_remaining "$week_all_raw")
week_sonnet_reset=$(calc_remaining "$week_sonnet_raw")

# Only update cache if we got valid data
if [[ "$session_pct" =~ ^[0-9]+$ ]]; then
  cat > "$CACHE_FILE" << JSON
{"session": "$session_pct", "week_all": "${week_all_pct:-?}", "week_sonnet": "${week_sonnet_pct:-?}", "session_reset": "${session_reset:-?}", "week_all_reset": "${week_all_reset:-?}", "week_sonnet_reset": "${week_sonnet_reset:-?}", "updated": "$(date '+%H:%M')"}
JSON
  # Signal SwiftBar to blink, then refresh after 10s to show normal icon
  touch /tmp/claude-usage-blink
  open -g "swiftbar://refreshplugin?name=claude-usage.5s"
  ( sleep 11 && open -g "swiftbar://refreshplugin?name=claude-usage.5s" ) &>/dev/null &
fi
