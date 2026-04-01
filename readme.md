# Claude Usage Monitor

Menu bar widget that shows Claude Code token usage with color-coded status via SwiftBar.

## Quick Install

**Double-click `install.command`** — it handles everything:
- Installs SwiftBar and jq (via Homebrew) if missing
- Copies the fetcher script to `~/.local/bin/`
- Symlinks the SwiftBar plugin
- Creates and loads the launchd agent (auto-refresh every 3 minutes)
- Starts SwiftBar

## Display Format

```
🟢 7%(11am)┊34%(3d)┊19%(1d)
   ▲           ▲        ▲
   session     week     sonnet
```

- **Session**: current session usage, resets at shown time (e.g. 11am)
- **Week (all models)**: weekly usage, shows days until reset (e.g. 3d)
- **Week (Sonnet only)**: sonnet-specific weekly usage

### Color Thresholds

| Icon | Range  |
|------|--------|
| 🟢   | < 50%  |
| 🟡   | 50-80% |
| 🔴   | > 80%  |

### Blink on Update

When new data arrives, the menu bar shows `⚡` (cyan) for **10 seconds**, then automatically switches back to the color-coded icon (🟢/🟡/🔴). This is purely local (reads a flag file + cached JSON) — no API calls or tokens consumed.

## How It Works

1. **Fetcher** (`claude-usage-fetch.sh`) spawns a Claude Code session, runs `/usage`, parses the output, writes to `/tmp/claude-usage-cache.json`, and drops a blink flag
2. **SwiftBar plugin** (`claude-usage.3m.sh`) reads the cache, checks the blink flag, and renders the menu bar widget
3. **launchd** runs the fetcher every 3 minutes automatically

### Token Cost

Each fetch spawns one minimal Claude session (~5 output tokens). On Claude Team/Max plan this is negligible. The blink mechanism and SwiftBar display consume zero tokens — they only read local files.

## Files

| File | Purpose |
|------|---------|
| `claude-usage.3m.sh` | SwiftBar plugin (display + blink) |
| `claude-usage-fetch.sh` | Fetcher (data collection) |
| `install.command` | One-click installer (double-click to run) |

Installed locations:

| Source | Installed to |
|--------|-------------|
| `claude-usage.3m.sh` | `~/Library/Application Support/SwiftBar/Plugins/claude-usage.3m.sh` (symlink) |
| `claude-usage-fetch.sh` | `~/.local/bin/claude-usage-fetch-real.sh` (copy) |
| (generated) | `~/Library/LaunchAgents/com.ichigo.claude-usage-fetch.plist` |

## Dependencies

- [SwiftBar](https://github.com/swiftbar/SwiftBar) — `brew install --cask swiftbar`
- `jq` — `brew install jq`
- `perl` — built into macOS
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) — `npm install -g @anthropic-ai/claude-code`

## Configuration

Edit `install.command` to change:
- `REFRESH_INTERVAL` — fetcher interval in seconds (default: 180 = 3 min)
- `SWIFTBAR_INTERVAL` — plugin refresh interval (default: `3m`)

The fetcher runs from `~/Documents/repo/oms` (a Claude Code trusted directory). To change this, edit the `cd` line in `claude-usage-fetch.sh`.

## Manual Refresh

Click the menu bar icon → **Refresh** to trigger an immediate fetch.

## Troubleshooting

### Menu bar shows `☁️ --%`
Cache is empty. Wait for the first fetch (~30s) or run manually:
```bash
~/.local/bin/claude-usage-fetch.sh
```

### Reset time shows `?`
The ANSI output parsing may have failed. Check raw output:
```bash
cat /tmp/claude-usage-session.txt | perl -pe 's/\e\[[^a-zA-Z]*[a-zA-Z]//g' | grep -i reset
```

### Fetcher stuck
Remove the lock file:
```bash
rm -f /tmp/claude-usage-fetch.lock
```

### Verify launchd
```bash
launchctl list | grep claude-usage
```

### Restart everything
```bash
launchctl unload ~/Library/LaunchAgents/com.ichigo.claude-usage-fetch.plist
launchctl load ~/Library/LaunchAgents/com.ichigo.claude-usage-fetch.plist
killall SwiftBar; open -a SwiftBar
```

### Check logs
```bash
cat /tmp/claude-usage-fetch.log     # fetcher log
cat /tmp/claude-usage-cache.json    # cached data
```

## Auto-start

SwiftBar is added to Login Items and starts automatically on boot.
The launchd fetcher (`com.ichigo.claude-usage-fetch.plist`) also runs at load.
