# MicroCeph contribution clinic

Small groups. Each group takes one real open issue in
[canonical/microceph](https://github.com/canonical/microceph), fixes it,
and opens a pull request. Everything runs from an offline bundle.

## 1. Prep

1. **Fork** https://github.com/canonical/microceph.
2. **Download the bundle** from the
   [release page](https://github.com/hillpd/microceph-workshop/releases/tag/clinic-2026-10-29):
   - [microceph-artifacts-full.tar.gz](https://github.com/hillpd/microceph-workshop/releases/download/clinic-2026-10-29/microceph-artifacts-full.tar.gz)
     for the Go and shell groups (1, 2, 4). If in doubt, take this one
   - [microceph-artifacts-lite.tar.gz](https://github.com/hillpd/microceph-workshop/releases/download/clinic-2026-10-29/microceph-artifacts-lite.tar.gz)
     for the docs, Python and CI groups (3, 5, 6), a fraction of the size
3. **Launch a container and put the bundle in it.** Everything runs inside
   it; nothing in the kit touches your machine. Any LXD host will do:
   ```
   lxc launch ubuntu:24.04 microceph-clinic
   lxc file push microceph-artifacts-full.tar.gz microceph-clinic/home/ubuntu/     # or -lite
   lxc exec microceph-clinic -- su - ubuntu
   ```
   To push from inside, use a fine-grained token scoped to your fork over
   HTTPS, or `lxc file pull` the clone out and push from your machine.
   Don't forward an SSH agent into it: the container runs the bundle's
   packages, a prebuilt linter and the repo's own tests, none of which
   you have audited.
4. **Run prep, inside the container:**
   ```
   tar -xzf microceph-artifacts-full.tar.gz && ~/microceph-artifacts/kit/prep.sh
   ```
   It refuses to run outside a container. Inside, it clones MicroCeph from
   the bundle into `~/microceph-workshop/microceph` (add your fork as
   `origin` yourself), installs the bundle's Ubuntu packages with sudo, a
   Go toolchain, a prebuilt golangci-lint and a Python venv, then compiles
   and tests everything once. The bundle's checksums show the download is
   complete; it is not signed. On your machine the only changes are the
   container and its cached image; `lxc delete -f microceph-clinic`
   removes them. Most of the time is the first compile. Safe to run again.
   It ends with `READY`. If it says `NOT READY`, each `FAIL` line has an
   entry in [troubleshooting](guide/troubleshooting.md); if that does not
   sort it, send me the full output.
5. **Pick a group** (table below) and open its brief and issue thread.

More detail: [`guide/01-prep.md`](guide/01-prep.md).

## 2. The clinic

A short intro, then each group works on its issue (I'll be around to help),
and we finish with a live review of a couple of PRs. Every group has
the same goals, in this order. All commands are in
[`guide/cheatsheet.md`](guide/cheatsheet.md), one page.

| Goal | How | Page |
|---|---|---|
| Working environment | `./clinic preflight` says `READY`; `./clinic unit common` prints `ok` | [guide/01](guide/01-prep.md) |
| Issue understood | Read your brief and the issue thread | [guide/02](guide/02-your-issue.md) |
| On a branch | `git checkout -b fix-NNN main` in `~/microceph-workshop/microceph` | [guide/03](guide/03-branch.md) |
| Problem shown | The brief's "first job": prove the problem is still real with a failing test or a reproduced symptom | [guide/04](guide/04-reproduce.md) |
| Fixed, with a test | Smallest change that makes it pass. Run your track's checks before every commit | [guide/05](guide/05-fix-and-test.md), [guide/06](guide/06-validate.md) |
| Committed | `git commit -s`, title `<area>: <imperative summary>`, body says why, `Fixes #NNN` | [guide/07](guide/07-commit.md) |
| PR open | Push to your fork, open the PR against `canonical/microceph:main` | [guide/08](guide/08-open-the-pr.md) |

Before the review block, commit and push whatever state you are in. A
pushed branch can be picked up later; an unpushed one is gone.

The project's rules are in `CONTRIBUTING.md` and `AGENTS.md` in the repo;
the cheat sheet has the short version. Two that bite first-time PRs:
`git commit -s` on every commit, and `Assisted-by: tool:model` above your
sign-off if an AI tool helped.

### Groups

One brief per issue. The brief gives the problem, where to look, how to
show it, and the definition of done. It does not give the fix.

| Group | Issue | Track | Brief |
|---|---|---|---|
| 1 | #649 cluster export rejects hyphens | Go | [brief](groups/01-649-cluster-name-hyphens.md) |
| 2 | #243 `disk list` shows CD-ROMs: verify it is fixed, add the regression test, close | Go | [brief](groups/02-243-disk-list-unsupported.md) |
| 3 | #505 log level integers undocumented | Go + docs | [brief](groups/03-505-log-levels.md) |
| 4 | #808 `osd.start` and LUKS unlock after a failed OSD | shell | [brief](groups/04-808-osd-start-luks.md) |
| 5 | #912 `checks.yml` apt flakiness and Go cache | CI YAML | [brief](groups/05-912-checks-yml.md) |
| 6 | #911 and #909 harness diagnostics and apt retries | Python | [brief](groups/06-911-909-harness.md) |

## 3. After

When the review comes in, answer the comments, amend, push again. [`guide/09-after-the-clinic.md`](guide/09-after-the-clinic.md)
has the details. Follow-up chat: [#ceph-devel:ubuntu.com](https://matrix.to/#/#ceph-devel:ubuntu.com) on Matrix.
