# Subtext — Record

## 2026-04-18 — Status line polish session

Started with a single bug: switching to the non-1M Opus 4.6 still rendered
`Opus 4.6 (1M)` in the status line. Expanded into a broader round of
polish.

### Round 1 — shipped in PR #1 (merged to `main`)

- **Model label bug.** The `case` block matched `*Opus*4.6*` and hard-coded
  `(1M)` onto every Opus 4.6 display name. Fixed by adding a `*1[Mm]*`
  glob before the generic match, and extended the same treatment to
  Opus 4.7 and Sonnet 4.6. Opus 4.7 wasn't previously handled at all.
- **Effort segment.** The status line JSON doesn't expose the current
  `effortLevel`, so we read it directly from `~/.claude/settings.json`.
  Renders as `E:xhigh` (matching the `CTX:` / `5h:` label style) and is
  omitted when unset. This is global across models and sessions —
  `/effort` writes back to `settings.json`, so live changes show up on
  the next refresh. Known caveat: concurrent Claude Code sessions share
  one file (see Claude Code issue #37303).
- **Conditional hours-until-reset.** The `-Nh` countdown after each rate
  limit was always shown. Hid it while pace is in the green zone (delta
  ≤ 10); it reappears at yellow / orange / red. Green was quiet noise.
- README updated to reflect all of the above.

Pushed to `feat/initial-release`, PR #1 opened and merged to `main`.
Users installing via `install.sh` now get these changes.

### Round 2 — two-line status line (local only)

User wanted git branch, a session timer, and task counter on a second
line. Claude Code's status line supports multi-line output natively
(any newline in the script's stdout is rendered as a new row).

Decisions:
- **Line 1:** `<𝕊> | CTX | 5h | 7d | Model | Effort` (health / config).
- **Line 2:** `branch[*] | timer | $price | task:done/total` (working
  context). Price moved down from line 1 at user request.
- **Branch + dirty:** `git -C "$cwd"` against `workspace.current_dir`
  from the JSON input (avoids relying on shell `pwd`). `*` if
  `git status --porcelain --untracked-files=no` is non-empty.
- **Timer:** derived from `stat -f %B` (macOS birth time) on the
  session's `.jsonl` file at
  `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`. Path encoding
  replaces `/`, `_`, `.` with `-` to match Claude Code's layout. Formats
  as `45m` under an hour, `1h23m` above.
- **Tasks:** counts `- [ ]` vs `- [xX]` in `tasks.md` at the project
  root. Segment omitted if the file is missing or has zero matches.
- **Line 2 emission:** price is always added, so line 2 always renders.
  Branch / timer / task are all conditional.

Prototype works against live test payloads. Not yet synced to
`subtext/statusline.sh`, README not updated, nothing committed.

### Round 2a — line 2 alignment

Goal was to get line 2's leading `|` to sit under line 1's first `|` so
the data columns read coherently. Tried and failed:
- **Regular spaces:** trimmed by the status line renderer.
- **Non-breaking space (U+00A0):** also trimmed.
- **Em-space (U+2003):** also trimmed.
- **Superscript "subtext" (ˢᵘᵇᵗᵉˣᵗ) as a visible anchor:** worked but
  looked bad — the mixed-height characters (tall `ᵇ` next to shorter
  `ˢᵘ`) read as broken.
- **Repeated logo on line 2 (`<𝕊>` twice):** clean alignment but felt
  redundant.

What worked: **Braille Pattern Blank (U+2800).** Renders as whitespace
but isn't classified as a space, so the trimmer leaves it alone. 4
braille blanks land the `|` under line 1's pipe in Jason's font.

Documented the trick in README so future maintainers aren't confused by
the "why not just use spaces" question.

### PR links
- #1 — https://github.com/subsequence-ai/subtext/pull/1 (merged)
- #2 — will be opened for Round 2 + 2a
