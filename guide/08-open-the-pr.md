# 8. Open the pull request

Before the review block. If you are not done, commit what you have and push anyway.

## 8.1 Push to your fork

```
git push -u origin fix-NNN
```

If you cannot reach GitHub, bundle the branch and hand me the file, then
push and open the PR when you have a connection
([step 9.1](09-after-the-clinic.md)):

```
git bundle create ~/fix-NNN.bundle main..fix-NNN
```

I review it with
`git fetch ~/fix-NNN.bundle fix-NNN:review/fix-NNN` and `git log -p review/fix-NNN`.

## 8.2 Open the PR

Open the PR against `canonical/microceph:main`. Title: the commit title.

Fill in the template (`.github/PULL_REQUEST_TEMPLATE.md`) rather than
replacing it:

- **Description**: two or three sentences. Put your "Before" and "After"
  lines from steps 4 and 6 here, then `Fixes #NNN` on its own line.
- **Type of change**: one bullet.
- **How has this been tested?**: the commands you ran (`make check-unit`,
  `make check-static`, `go vet`, `shellcheck`, `pytest`, `sphinx-build`)
  or the manual steps for shell changes.
- **Contributor checklist**: for docs pages, the items about HTML meta
  descriptions and page titles apply to you.

## 8.3 Watch the checks

**If this is your first PR to canonical/microceph, nothing will run until a
maintainer approves the workflows.** The PR page shows "workflows awaiting
approval". Tell me and I will ask a maintainer. It may not happen during
the clinic.

Once approved, these run:

- **Commits**: DCO (`Signed-off-by` on every commit). Red means step 7.1.
- **Canonical Contributor Licence Agreement check**: red means the commit
  email is not one your GitHub account lists.
- **Checks**: `static-checks` (`make check-static` plus `go vet ./...`) and
  `unit-tests` (`make check-unit` plus the pytest suites), the same things
  you ran.
- **Vuln scan (PR diff)**: when you changed Go files.
- **Automatic doc checks**: when you changed `docs/`.
- **Tests**: the Robot integration suites in LXD VMs.

`Checks` also runs on plain pushes, so if Actions are enabled on your fork,
the push of `fix-NNN` shows the static and unit result on your fork's
Actions tab without waiting for anyone.

## 8.4 If a check fails

Amend and force-push, do not add a "fix CI" commit:

```
git add <file>
git commit --amend -s
git push --force-with-lease origin fix-NNN
```

## Checkpoint

- [ ] Branch is pushed to `origin` (or bundled and handed over, with a note to push later)
- [ ] PR open against `canonical/microceph:main`
- [ ] Title matches the commit title
- [ ] Template filled: description with Before and After, `Fixes #NNN`, type of change, how tested, checklist
- [ ] Workflows are either green or "awaiting approval" (first PR)
