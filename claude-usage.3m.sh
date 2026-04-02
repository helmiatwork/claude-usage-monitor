#!/bin/bash

# Claude Code Usage Monitor for SwiftBar
# Reads cached usage data written by the fetcher daemon

CACHE_FILE="/tmp/claude-usage-cache.json"
BLINK_FLAG="/tmp/claude-usage-blink"
CONFIG_FILE="$HOME/.config/claude-usage/config"
FETCHER="/Users/ichigo/.local/bin/claude-usage-fetch.sh"

# Read refresh interval from config (default 5 minutes)
if [ -f "$CONFIG_FILE" ]; then
  _mins=$(grep -oE '^refresh_minutes=[0-9]+' "$CONFIG_FILE" | cut -d= -f2)
fi
FETCH_INTERVAL=$(( ${_mins:-5} * 60 ))

# --- Handle commands from menu actions ---
if [ "$1" = "set_interval" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  echo "refresh_minutes=$2" > "$CONFIG_FILE"
  exit 0
fi

if [ "$1" = "refresh_now" ]; then
  # Show ⚡ immediately while fetcher runs
  touch "$BLINK_FLAG"
  open -g "swiftbar://refreshplugin?name=claude-usage"
  "$FETCHER" &>/dev/null &
  exit 0
fi

# --- Read cache ---
if [ -f "$CACHE_FILE" ]; then
  session_pct=$(jq -r '.session // "?"' "$CACHE_FILE" 2>/dev/null)
  week_all_pct=$(jq -r '.week_all // "?"' "$CACHE_FILE" 2>/dev/null)
  week_sonnet_pct=$(jq -r '.week_sonnet // "?"' "$CACHE_FILE" 2>/dev/null)
  session_reset=$(jq -r '.session_reset // "?"' "$CACHE_FILE" 2>/dev/null)
  week_all_reset=$(jq -r '.week_all_reset // "?"' "$CACHE_FILE" 2>/dev/null)
  week_sonnet_reset=$(jq -r '.week_sonnet_reset // "?"' "$CACHE_FILE" 2>/dev/null)
else
  session_pct="?"
  week_all_pct="?"
  week_sonnet_pct="?"
  session_reset="?"
  week_all_reset="?"
  week_sonnet_reset="?"
fi

# --- Color based on highest usage ---
max_pct=0
for p in "$session_pct" "$week_all_pct" "$week_sonnet_pct"; do
  if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -gt "$max_pct" ]; then
    max_pct=$p
  fi
done

if [ "$max_pct" -ge 80 ]; then
  icon="🔴"
elif [ "$max_pct" -ge 50 ]; then
  icon="🟡"
else
  icon="🟢"
fi

# --- Blink detection (10s after data updated) ---
blink=false
if [ -f "$BLINK_FLAG" ]; then
  flag_age=$(( $(date +%s) - $(stat -f%m "$BLINK_FLAG") ))
  if [ "$flag_age" -lt 10 ]; then
    blink=true
  else
    rm -f "$BLINK_FLAG"
  fi
fi

# --- Title bar ---
display="${session_pct}%(${session_reset})┊${week_all_pct}%(${week_all_reset})┊${week_sonnet_pct}%(${week_sonnet_reset})"

if [ "$session_pct" = "?" ]; then
  echo "☁️ --% | color=#888888"
elif [ "$blink" = true ]; then
  echo "⚡ $display | color=#00ffcc"
else
  echo "$icon $display | color=white"
fi

# --- Dropdown ---
echo "---"
echo "Claude Code Usage | size=14"
echo "---"
echo "Session:       ${session_pct}% (reset ${session_reset})"
echo "Week (all):    ${week_all_pct}% (reset ${week_all_reset})"
echo "Week (sonnet): ${week_sonnet_pct}% (reset ${week_sonnet_reset})"
echo "---"
if [ -f "$CACHE_FILE" ]; then
  updated=$(jq -r '.updated // "?"' "$CACHE_FILE" 2>/dev/null)
  updated_epoch=$(stat -f%m "$CACHE_FILE")
  now_epoch=$(date +%s)
  elapsed=$(( now_epoch - updated_epoch ))
  remaining=$(( FETCH_INTERVAL - elapsed ))
  if [ "$remaining" -le 0 ]; then
    remaining=0
    touch "$BLINK_FLAG"
    "$FETCHER" &>/dev/null &
  fi
  mins=$(( remaining / 60 ))
  secs=$(( remaining % 60 ))
  countdown=$(printf "%d:%02d" "$mins" "$secs")
  echo "Updated: $updated | size=11 color=#888888"
  echo "Next refresh: $countdown | size=11 color=#888888"
fi
SELF_PATH="/Users/ichigo/Library/Application Support/SwiftBar/Plugins/claude-usage.5s.sh"
echo "Refresh | bash='$SELF_PATH' param1=refresh_now terminal=false refresh=true"
echo "---"
current_mins=$(( FETCH_INTERVAL / 60 ))
echo "Refresh every: ${current_mins}m | size=11 color=#888888"
for m in 3 4 5 6 7 8 9 10; do
  if [ "$m" -eq "$current_mins" ]; then
    echo "-- ✓ ${m} min | disabled=true"
  else
    echo "-- ${m} min | bash='$SELF_PATH' param1=set_interval param2=$m terminal=false refresh=true"
  fi
done
