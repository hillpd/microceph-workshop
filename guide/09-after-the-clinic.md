# 9. After the clinic

## 9.1 If you could not push at the clinic

When you have a connection:

```
cd ~/microceph-workshop/microceph
git push -u origin fix-NNN
```

Then open the PR as in [step 8](08-open-the-pr.md).

## 9.2 Review

Review usually arrives within a few days. Amend and force-push with lease
as in [step 8.4](08-open-the-pr.md), after re-running your track's checks.

## 9.3 Rebase if main moved

If GitHub says the branch has conflicts or a reviewer asks for a rebase:

```
git fetch upstream
git rebase upstream/main
(cd microceph && make check-unit && make check-static)
git push --force-with-lease origin fix-NNN
```

Rebase, never merge.

## 9.4 If it stalls

No response after a week: ping the PR. Still nothing after two: ask in Matrix `#ceph-devel:ubuntu.com` with the
PR link. I am chasing all clinic PRs too.

## 9.5 Next

- Open issues: https://github.com/canonical/microceph/issues
- Two held-back clinic issues if you want a second one: #420
  (`pool set-rf --set-default`) and #558 (maintenance preflight ignores
  peers already in maintenance). Ask on the issue first.
- Docs: https://canonical.com/ceph/docs/latest/contributing/
- Chat: Matrix [#ceph-devel:ubuntu.com](https://matrix.to/#/#ceph-devel:ubuntu.com)
