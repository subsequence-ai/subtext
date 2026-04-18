# Subtext — Tasks

## Status line polish (merged to `main` via PR #1)

- [x] Distinguish 1M vs non-1M for Opus 4.6 — statusline.sh:24-25
- [x] Add Opus 4.7 model detection (1M + non-1M) — statusline.sh:22-23
- [x] Distinguish 1M vs non-1M for Sonnet 4.6 — statusline.sh:26-27
- [x] Display `effortLevel` from `~/.claude/settings.json` — statusline.sh:17-18, 118
- [x] Hide rate-limit hours-until-reset while pace is in green — statusline.sh:83-85
- [x] Update README for effort segment and conditional hours — README.md
- [x] Open PR #1 and merge to `main` — https://github.com/subsequence-ai/subtext/pull/1

## Multi-line status line

- [x] Extract `workspace.current_dir` in jq block — statusline.sh:10
- [x] Emit second line conditionally — statusline.sh:129-180
- [x] Git branch + dirty indicator segment — statusline.sh:132-140
- [x] Session timer segment (from session `.jsonl` birth time) — statusline.sh:142-159
- [x] Move price from line 1 to line 2 — statusline.sh:161-162
- [x] Task counter from `tasks.md` (`Task:done/total`) — statusline.sh:164-174
- [x] Align line 2's leading `|` under line 1's first `|` using Braille Pattern Blank (U+2800) padding — statusline.sh:176-178
- [x] Sync updated statusline to `subtext/statusline.sh`
- [x] Update README: two-line example, line 1 / line 2 segment tables, alignment note, customization updates
- [x] Commit, push, and merge to `main`
