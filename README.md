# <img src="logo.png" alt="Subtext" height="40" align="bottom"> Subtext

A status line for [Claude Code](https://claude.ai/code). It shows you what's actually happening in your session at a glance — how loaded your context is, whether you're on pace with your rate limits, and where you are in your current work.

```
<𝕊> | Tokens:87k | 5h:24% | 7d:55% | Opus 4.7 (1M) | E:xhigh
    | feat/initial-release* | 42m | $0.12 | Task:3/8
```

Built for **Substrate** — a Claude Code operating environment by [Subsequence.ai](https://subsequence.ai). Substrate is in beta, and Subtext is its first public component. It works standalone with any Claude Code setup.

## What you see

**Line 1 — session health**

- `Tokens:87k` — how many tokens are in your context right now, color-coded. Green under 90k, yellow up to 130k, orange up to 160k, red above. Claude's accuracy starts degrading past ~200k regardless of the model's window size, so the thresholds are absolute tokens — not a percentage of the window.
- `5h:24%` / `7d:55%` — rate limit usage, colored by pace. Green means you're on track. If you're burning faster than the window is elapsing, the color warms and the hours-until-reset appears (`5h:60% -2h`).
- `Opus 4.7 (1M)` — your active model.
- `E:xhigh` — current effort level. Hidden when unset.
- `agents(2): alpha, beta` — active agents in the session (subagents, named agents, etc.). Hidden when none are running.

**Line 2 — working context**

- `feat/initial-release*` — git branch. `*` means there are uncommitted changes.
- `42m` — time since the session started.
- `$0.12` — what this session would cost at API pricing. Your Pro/Max plan covers it, but it's worth watching.
- `Task:3/8` — completed vs total checkboxes in `tasks.md` at the project root. Hidden when there's no task file.

Any segment without data gets dropped rather than shown empty.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/subsequence-ai/subtext/main/install.sh | bash
```

Downloads the script, configures Claude Code to use it, and backs up your existing status line. Requires `jq` (`brew install jq` on macOS, `apt install jq` on Linux).

### Manual

1. Copy `statusline.sh` to `~/.claude/statusline.sh` and `chmod +x` it.
2. Add this to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh"
     }
   }
   ```

Changes take effect on your next interaction with Claude Code.

## Customize

`statusline.sh` is about 200 lines of bash with no dependencies beyond `jq`. Adjust color thresholds, reorder segments, rename labels — just read the script and edit.

## Requirements

- Claude Code (Pro or Max subscription for rate limit data)
- `jq`
- Bash
- macOS or Linux

## License

MIT
