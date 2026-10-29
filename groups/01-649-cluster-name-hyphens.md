# Group 1: #649 Cluster export fails when the cluster name contains hyphens

https://github.com/canonical/microceph/issues/649

## The problem

`microceph cluster export my-cluster` fails with
`cluster names can only have [a-z] or [0-9] characters`. The same check,
`ClusterNameRegex` (`^[a-z0-9]{1,63}$`), gates the remote name on
`remote import` and the `--local-name` argument, so hyphens are rejected
there too. The reporter first blamed the local (bootstrap) name, then
corrected that: the failing value is the name passed to `cluster export`.

The last maintainer comment (2026-01-27) argues for alphanumeric only,
because MicroCeph passes the name to Ceph as `--cluster` and `--client`.
What the code does today:

- The name is used as file names (`<name>.conf`, `<name>.keyring`,
  `rbd_mirror/<name>_peer_keyring`), as `--cluster`, `--id` and
  `--site-name` arguments to `rbd`/`ceph`, and in string comparisons
  against `site_name` from `rbd mirror pool info`. Nothing parses or
  splits it.
- CephFS mirroring already creates a Ceph client with hyphens in it:
  `client.fsmir-<volume>-<remote>` (`ceph/cephfs_snapshot.go:52`).
- The project's own how-tos, `docs/snap/how-to/configure-rbd-mirroring.rst`
  and `docs/snap/how-to/perform-site-failover.rst`, use `primary_cluster`
  and `secondary_cluster` as names, which the current rule rejects. No
  docs page states the naming rule itself.

Decision: allow hyphens between letters and digits, no leading or
trailing hyphen, 63 characters at most. Uppercase, `_`, `.`, `/` and
spaces stay rejected.

## Where

- `microceph/constants/constants.go:93-101`: doc comment, `ClusterNameRegex`,
  the compiled `clusterNameRegex`, `IsValidClusterName`.
- Error strings that spell out the old rule: `api/cluster.go:33`,
  `api/remote.go:156`, `api/remote.go:178`, `ceph/rbd_mirror.go:819`.
- Other caller, generic message: `database/remote_extras.go:74`.
- Tests: `api/remote_test.go` (`TestValidateRemoteNameRejectsTraversalAndReservedNames`
  line 10, `TestValidateRemoteNameAcceptsClusterNames` line 32). There is no
  test file in `constants/`; yours is `microceph/constants/constants_test.go`.
- Docs that describe remote names: `docs/snap/reference/commands/remote.rst`,
  `docs/snap/how-to/import-remote-cluster.rst`.
- CI gate: the `Checks` workflow, jobs `Run static checks` and `Run Unit tests`.

## First job

Show the rule rejecting a hyphenated name with no cluster: a unit test on
`IsValidClusterName` that expects `my-cluster` to be valid fails on main.
`grep -rn "IsValidClusterName\|ClusterNameRegex" microceph --include=*.go`
lists every place the rule reaches.

## Definition of done

- [ ] `cluster export`, `remote import` and `--local-name` accept names
      such as `my-cluster` and `a-b-c`.
- [ ] Still rejected: `-a`, `a-`, empty, 64 characters, uppercase, `_`,
      `.`, `/`, spaces. 63 characters still accepted.
- [ ] The four error strings state the new rule.
- [ ] A test pins the accept and reject cases, edges included;
      `api/remote_test.go` matches the new rule.
- [ ] Green: `(cd microceph && go test -count=1 ./constants/... ./api/... ./ceph/... ./database/...)`,
      then `(cd microceph && make check-unit)` and `(cd microceph && make check-static)`.
- [ ] The PR says whether the two how-tos' `primary_cluster` names are
      fixed here or left for a docs PR.
- [ ] Commit title `fix: <summary>`, body ends `Fixes #649`.
- [ ] The PR description answers the 2026-01-27 maintainer comment with
      the facts above.

## Watch out

- `api/remote_test.go:17` lists `"remote-name"` as a name that must be
  rejected. It becomes valid, so that test goes red with the fix.
- `TestValidateRemoteNameAcceptsClusterNames` slices `validNames[:4]` and
  `validNames[4]` by position; adding an entry shifts the "too long" case.
- `constants.go` keeps both the exported `const` string and the compiled
  `var`; the doc comment above them still says `a-z0-9`.
- `make check-unit` caches test results; use `go test -count=1` while iterating.
- Decide: is `a--b` (consecutive hyphens) valid? Pick one, pin it in the
  test, and say why in the PR.
- Decide: do the how-tos' `primary_cluster` names get fixed in this PR or
  a separate docs one?
