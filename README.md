<p align="center">
  <img src="logo.png" alt="Subtext" width="200">
</p>

# Subtext

A status line for [Claude Code](https://claude.ai/code) built for **Substrate** — a Claude Code operating environment by [Subsequence.ai](https://subsequence.ai). Substrate is currently in beta, and Subtext is its first public component.

Subtext shows you what actually matters: context health, rate limit pacing, and active agents — all from data Claude Code already provides. No API calls, no tokens spent, no external dependencies beyond `jq`.

```
<𝕊> | CTX:8% | 5h:24% | 7d:55% -120h | Opus 4.7 (1M) | E:xhigh
    | feat/initial-release* | 42m | $0.12 | Task:3/8
```

> **What is Substrate?** A curated layer of configs, hooks, skills, and workflows that sits on top of Claude Code — turning it from a general-purpose coding assistant into a structured development environment. Subtext works standalone with any Claude Code setup, but it was designed as part of that system.

## What it shows

Subtext renders on two lines. Line 1 is *health and configuration* — how the session is doing and what it's using. Line 2 is *working context* — where you are, how long you've been at it, what it's costing, and what's left to do.

**Line 1 — health / config**

| Segment | Example | Description |
|---------|---------|-------------|
| Context | `CTX:8%` | Context window usage (bold, color-coded) |
| 5h limit | `5h:24%` / `5h:24% -3h` | 5-hour rate limit usage. Hours until reset appear only when pace is outside green |
| 7d limit | `7d:55%` / `7d:55% -120h` | 7-day rate limit usage. Hours until reset appear only when pace is outside green |
| Model | `Opus 4.7 (1M)` | Active model |
| Effort | `E:xhigh` | Current `effortLevel` (read from `~/.claude/settings.json`) — omitted if unset |
| Agents | `agents(3): alpha, beta, general-purpose` | Active subagents in current session (only appears when agents are running) |

**Line 2 — working context**

| Segment | Example | Description |
|---------|---------|-------------|
| Branch | `feat/initial-release*` | Current git branch in the project's working directory. Trailing `*` indicates uncommitted tracked changes. Omitted when not in a git repo |
| Timer | `42m` / `1h15m` | Time since the current Claude Code session file was created. Omitted when the session file can't be located |
| Cost | `$0.12` | Session cost (at API pricing) |
| Task | `Task:3/8` | Completed vs total checkboxes in `tasks.md` at the project root. Omitted when the file is absent or has no checkboxes |

Line 2 is aligned so its leading `|` sits directly under line 1's first `|`, keeping the data columns visually coherent. Any segment on either line that has no meaningful data is omitted entirely rather than shown empty, which is why the line 2 order can differ from the headings above in practice.

**A note on cost:** Your Pro/Max subscription covers your usage — the cost displayed isn't what you're being charged. It's what the session *would* cost at API pricing. It's worth paying attention to: our tokens are subsidized today, but that won't last forever. Building awareness of what your usage actually costs helps you make better decisions about how you work.

## Install

The easy way — just run this in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/subsequence-ai/subtext/main/install.sh | bash
```

This downloads the statusline script, configures Claude Code to use it, and backs up your existing statusline if you have one. Requires `jq` (`brew install jq` on macOS, `apt install jq` on Linux).

### Manual install

If you'd rather do it yourself:

1. Copy `statusline.sh` to `~/.claude/statusline.sh`
2. Make it executable:
   ```bash
   chmod +x ~/.claude/statusline.sh
   ```
3. Add to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh"
     }
   }
   ```

Changes take effect on your next interaction with Claude Code.

## How it works

Claude Code pipes a JSON object to your statusline script via stdin on every assistant message. The script reads it, extracts what it needs, and prints formatted text. No network calls, no file writes (except reading the agent tracking file if it exists), no cost.

Subtext extracts all fields in a single `jq` call for performance, then assembles them in display order:

```
line 1:  logo | context | 5h | 7d | model | effort | agents?
line 2:  branch? | timer? | cost | task?
```

The rate limit fields (`rate_limits.five_hour`, `rate_limits.seven_day`) are provided natively by Claude Code for Pro/Max subscribers. No OAuth tokens or API calls needed.

The effort level, git branch, session timer, and task counter are all derived from sources outside the statusline JSON:
- **Effort:** `effortLevel` is read from `~/.claude/settings.json`. This reflects the setting that `/effort` writes, so live changes update on the next status refresh.
- **Branch:** `git -C "$workspace.current_dir"` provides branch name and a dirty check — no shell state assumptions.
- **Timer:** derived from the birth time (`stat -f %B` on macOS) of the current session's transcript file at `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`.
- **Task:** counted from `- [ ]` / `- [xX]` entries in `tasks.md` at the project root (a convention used by Substrate).

### Aligning the second line

Claude Code's status line renderer aggressively trims leading whitespace — regular spaces, non-breaking spaces, and em-spaces all get stripped. To keep line 2's leading `|` aligned under line 1's, Subtext pads with **Braille Pattern Blank (U+2800)**, which renders as whitespace but isn't classified as a space by the trimmer. Adjust the count in the `indent=` line if your font renders those blanks at a different width.

## Color logic

Subtext uses two different color strategies because context and rate limits are fundamentally different problems.

### Context: threshold-based

Context usage gets aggressive thresholds because degradation is irreversible within a session. Research on Claude Opus 4.6 with the 1M context window shows:

- Benchmarks drop from 93% accuracy at 256K tokens to 76% at 1M
- Community reports noticeable degradation starting around 200K tokens (~20%)
- The "lost in the middle" effect means buried context gets progressively harder to recall
- Auto-compaction triggers at ~83%, but it operates blind — manual `/compact` with a focus prompt is better

The thresholds are set to keep you well ahead of degradation:

| Color | Range | ~Tokens (1M) |
|-------|-------|-------------|
| Green | 0–9% | 0–90K |
| Yellow | 10–13% | 100–130K |
| Orange | 14–16% | 140–160K |
| Red | 17%+ | 170K+ |

These thresholds are deliberately aggressive — they're designed for **Substrate**, where tasks are broken into bite-sized chunks and sessions are kept short to maximize Claude's performance. Context is cheap to rebuild; degraded accuracy is expensive to recover from.

**What to do in Substrate:**

| Color | Action |
|-------|--------|
| Green | Keep working |
| Yellow | Wrap up the current task, commit your work |
| Orange | Finish what you're doing and `/clear` — start a fresh session |
| Red | `/clear` now. Context is degrading. Don't start new work in this session |

Substrate never runs `/compact`. The philosophy is: if your context is getting long, your task was too big. Break it smaller, clear, and start fresh with a clean prompt. Compaction loses information unpredictably — a clean restart with a good handoff loses nothing.

Substrate uses session tracking (`record.md`, `tasks.md`) and the `/update` command to maintain continuity across short, focused sessions. This is why `/clear` is preferred over `/compact` — context is rebuilt from records, not preserved through compaction.

**What to do in standard Claude Code:**

| Color | Action |
|-------|--------|
| Green | Keep working |
| Yellow | Stay aware — session is growing |
| Orange | Run `/compact` with a focus prompt (e.g., `/compact focus on the API refactoring`) to preserve what matters |
| Red | `/compact` or `/clear`. If compacting, be specific about what to keep |

If you'd rather let context run higher in either setup, adjust `color_for_ctx()` in the script.

### Rate limits: pace-based

Raw usage percentage is misleading for rate limits. 60% used sounds concerning — but if you're 80% through the time window, you're actually *under* pace.

Subtext compares your usage against where you *should* be:

```
pace_delta = usage% - elapsed%
```

- **60% used, 1 hour left in 5h window** = 80% elapsed, delta = -20 → green (you're fine)
- **60% used, 4 hours left in 5h window** = 20% elapsed, delta = +40 → red (burning hot)

| Color | Pace delta | Meaning |
|-------|-----------|---------|
| Green | 10 or less | On pace or behind — no concern |
| Yellow | 11–20 | Slightly ahead of pace |
| Orange | 21–35 | Moderately ahead — consider slowing down |
| Red | 35+ | Well ahead of pace — you'll hit the limit before reset |

The hours-until-reset display (e.g., `-3h`) rounds to the nearest hour so you can quickly gauge how much runway you have. It's hidden while you're in the green zone — when you're on pace, the countdown is just noise. It reappears automatically the moment your pace pushes into yellow, orange, or red.

## Agent tracking

Most custom status lines replace Claude Code's default display entirely — which kills visibility into active agents. If you run subagents regularly, that's a problem. Subtext shows you the metrics you need without sacrificing the visibility of active agents in your session.

This reads from a JSON tracking file at `/tmp/claude-active-agents-$USER.json` that gets populated by agent lifecycle hooks. Agents appear as: `agents(3): alpha, beta, general-purpose`

When no agents are running, the segment disappears.

## Customization

The script is ~180 lines of bash. Everything is straightforward to modify:

- **Colors**: Adjust thresholds in `color_for_ctx()` or `color_for_pace()`
- **Layout order**: Reorder the assembly lines in the `# Assemble` block (line 1) or the `line2_segments` pushes (line 2) to rearrange segments
- **Model names**: Add patterns to the `case` block under `# Shorten model name`
- **Hours visibility**: The `[ "$delta" -ge 11 ]` check in `rate_limit_display()` controls when the hours-until-reset text appears — adjust or remove to always show
- **Line 2 alignment**: Adjust the number of `brblank` entries in `indent=` to shift the second line left or right
- **Task source**: Line 2 reads `tasks.md` at `workspace.current_dir`. Point it elsewhere by editing the `[ -f "$cwd/tasks.md" ]` check
- **Dimming**: Most line 1/2 segments use `\033[90m` (bright black/gray) — change to any ANSI code

## Requirements

- Claude Code (Pro or Max subscription for rate limit data)
- `jq` (JSON parser)
- Bash
- A terminal that supports ANSI colors (basically all of them)
- macOS or Linux

## License

MIT
