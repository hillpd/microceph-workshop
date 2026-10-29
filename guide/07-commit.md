# 7. Commit

## 7.1 Commit with sign-off

```
git commit -s
```

The DCO check rejects a commit without a `Signed-off-by` trailer, or
whose trailer does not match the author.

The sign-off is yours. `AGENTS.md` says an AI tool must never add
`Signed-off-by` on a human's behalf, so if an agent made the commit, you
run `git commit --amend -s` yourself (and read the diff before you do).

## 7.2 The message

```
<area>: <what the change does, imperative, under 72 characters>

<Why. What was wrong, what this does about it. Two to five lines.
Wrap at 72. Plain ASCII, no smart quotes or em dashes.>

Fixes #NNN

Assisted-by: <tool>:<model>
Signed-off-by: Your Name <you@example.com>
```

Two git traps in that layout:

- `Fixes #NNN` is not a trailer. Keep the blank line after it; without
  one, `git commit -s` starts a new paragraph for the sign-off and
  `Assisted-by` stops being a trailer. `git interpret-trailers --parse`
  on the message should list both.
- In the editor, a line starting with `#` is a comment and git drops
  it. Never start a line with `#NNN`; write `issue #NNN`.

`<area>` is a type, the way the project's history uses it
(`git log --oneline -30`): `fix:`, `feat:`, `docs:`, `test:`, `ci:`,
`snap:` for the snap wrappers, `chore:`, `refactor:`. Most clinic PRs are
`fix:`, `test:`, `docs:` or `ci:`.

For example, a `test:` commit:

```
test: add regression test for CD-ROM exclusion in disk list

FilterAvailableDisks already drops read-only and undersized devices,
which covers optical drives. Pin that behaviour with a test so #243
cannot regress silently.

Fixes #243
```

`Fixes #NNN` only if the change fully closes the issue; otherwise
`Related: #NNN`.

If an AI tool helped write the change, add `Assisted-by: <tool>:<model>`
as the last line before your own sign-off, in the form `AGENTS.md` gives:
lowercase, hyphenated tool name, then the model:

```
Assisted-by: claude-code:<model>
Signed-off-by: Your Name <you@example.com>
```

Do not add other bot trailers such as `Co-Authored-By`; the project asks
for `Assisted-by` only, and extra trailers can confuse the CLA check.

## 7.3 One commit or several?

For the clinic issues, almost always one. Group 3 is the exception: one
commit for `docs/`, one for the CLI help text, because `CONTRIBUTING.md`
asks for commits split by area in non-trivial PRs.

## Checkpoint

- [ ] `git log -1 --format=%B | grep Signed-off-by` prints your name and email
- [ ] `git log -1 --format=%B | git interpret-trailers --parse` lists `Assisted-by` too, if an AI tool helped
- [ ] Title is `<area>: <imperative>`
- [ ] Body explains why
- [ ] `Fixes #NNN` present (or `Related: #NNN` when the PR does part of an issue, as in group 3's second commit and group 6)
- [ ] One commit (or the deliberate split for group 3)
