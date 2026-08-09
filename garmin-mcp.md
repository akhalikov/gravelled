# Garmin Connect MCP Setup

Connects Claude (desktop app) to Garmin Connect data — activities, sleep, HRV, body battery, training load, power analysis (110+ tools).

- Server: [Taxuspt/garmin_mcp](https://github.com/Taxuspt/garmin_mcp) (uses [python-garminconnect](https://github.com/cyberjunky/python-garminconnect))
- Set up: July 31, 2026, on MacBook Pro

## Installation (new laptop)

### 1. Prerequisites

```bash
brew install uv
```

### 2. Authenticate with Garmin (one-time)

```bash
uvx --python 3.12 --with "mcp<2" --from git+https://github.com/Taxuspt/garmin_mcp garmin-mcp-auth
```

- Enter Garmin email + password (+ MFA if enabled)
- 429 "IP rate limited" warnings are OK if it eventually succeeds
- Tokens saved to `~/.garminconnect` (plus portable base64 copy at `~/.garminconnect_base64`)
- Tokens valid **~6 months**; on expiry re-run with `--force-reauth`
- Verify anytime: `garmin-mcp-auth --verify`

### 3. Add MCP server to Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (or Settings → Developer → Edit Config) and add a top-level `mcpServers` key:

```json
"mcpServers": {
  "Garmin Connect": {
    "command": "/opt/homebrew/bin/uvx",
    "args": [
      "--python", "3.12",
      "--with", "mcp<2",
      "--from", "git+https://github.com/Taxuspt/garmin_mcp",
      "garmin-mcp"
    ]
  }
}
```

No credentials in config — the server uses saved tokens.

### 4. Restart

Cmd+Q the Claude app, relaunch, start a **new** conversation. Check Settings → Developer: "Garmin Connect" should show without a "failed" badge.

## Gotchas (learned the hard way)

1. **`--with "mcp<2"` is mandatory.** The repo pins `mcp>=1.23.0`, but MCP Python SDK 2.0 removed `mcp.server.fastmcp` → `ModuleNotFoundError: No module named 'mcp.server.fastmcp'`. The pin forces the 1.x SDK. (Check if the repo fixed this upstream before reusing.)
2. **Don't use the `.dxt` extension installer.** Its launch args are hardcoded without the `mcp<2` pin and can't be edited → "Server disconnected" crash loop. Remove it in Settings → Extensions and use the JSON config instead.
3. **Don't put `GARMIN_EMAIL`/`GARMIN_PASSWORD` in config env vars** — the extension did this and it's both unnecessary and insecure.
4. **`uvx` path**: Claude Desktop may not have your shell PATH; use the absolute path (`which uvx`, here `/opt/homebrew/bin/uvx`).
5. **Debug logs**: `~/Library/Logs/Claude/mcp-server-Garmin*.log`. Test the server manually with the exact command+args from config — if it prints "Garmin Connect client initialized successfully" and waits, it works.
6. **Training readiness is unavailable** — Fenix 6 doesn't support that metric. Everything else (sleep, HRV, body battery, stress, activities) works.

## Related

- Scheduled task `garmin-morning-brief`: daily ~9:00 health brief (sleep, HRV, RHR, body battery + day suggestion). Local task — runs only while the Claude app is open. Stored at `~/Claude/Scheduled/garmin-morning-brief/SKILL.md`.
- For laptop-independent syncing (e.g. auto-append rides to `rides.md`): GitHub Actions cron with `python-garminconnect` + base64 tokens as repo secret, or an Anthropic cloud Routine. Not set up yet.
