# Groups

One brief per issue, one issue per group (group 6 has two small ones).
Each brief gives the problem, where to look, how to show it, and the
definition of done. It does not give the fix; that is the group's work.

| Group | Issue | Track | Brief |
|---|---|---|---|
| 1 | #649 cluster export rejects hyphens | Go | `01-649-cluster-name-hyphens.md` |
| 2 | #243 `disk list` shows CD-ROMs: verify it is fixed, add the regression test, close | Go | `02-243-disk-list-unsupported.md` |
| 3 | #505 log level integers undocumented | Go + docs | `03-505-log-levels.md` |
| 4 | #808 `osd.start` and LUKS unlock after a failed OSD | shell | `04-808-osd-start-luks.md` |
| 5 | #912 `checks.yml` apt flakiness and Go cache | CI YAML | `05-912-checks-yml.md` |
| 6 | #911 and #909 harness diagnostics and apt retries | Python | `06-911-909-harness.md` |

Held back for a second clinic or a group that finishes early:
#420 (`pool set-rf --set-default`, touches CLI, API and daemon) and #558
(maintenance preflight ignores peers already in maintenance).

Workflow and commands: [`../guide/cheatsheet.md`](../guide/cheatsheet.md).
