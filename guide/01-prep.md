# 1. Prep

## 1.1 Fork the repo

Fork https://github.com/canonical/microceph. Commit with an email your
GitHub account lists (a noreply address is fine); the checks on the PR
look it up.

## 1.2 The container

Everything happens inside an `ubuntu:24.04` LXD container you launch;
the kit never runs anything on your machine. Download the bundle from the
[release page](https://github.com/hillpd/microceph-workshop/releases/tag/clinic-2026-10-29)
(**full** unless you are certain you are on the CI or Python group, 5
or 6, where **lite** is a fraction of the size and has no Go toolchain),
then:

```
lxc launch ubuntu:24.04 microceph-clinic
lxc file push microceph-artifacts-full.tar.gz microceph-clinic/home/ubuntu/
lxc exec microceph-clinic -- su - ubuntu
```

To push from inside, use a fine-grained token scoped to your fork over
HTTPS, or `lxc file pull` the clone out and push from your machine. Don't
forward an SSH agent into the container: it runs the bundle's packages, a
prebuilt linter and the repo's own tests, none of which you have audited.
Set your git name and email inside the container too.

## 1.3 Run prep

Inside the container:

```
tar -xzf microceph-artifacts-full.tar.gz        # or -lite
~/microceph-artifacts/kit/prep.sh
```

It refuses to run outside a container. It verifies the download (the
bundle's checksums; it is not signed), copies the kit to
`~/microceph-workshop`, clones
MicroCeph from the bundle with remotes `bundle` and `upstream` (add your
fork as `origin`), installs the toolchain from the bundle (a few debs
with sudo, Go under `~/.local/clinic/go`, a Python venv), compiles and
runs everything once, and prints a readiness report. Most of the time is
the first compile. It is safe to run again if something fails.

The report ends with `READY` or `NOT READY` and a list. Fix any `FAIL`
line (each has an entry in [troubleshooting](troubleshooting.md)) and
re-run. `warn` lines are informational.

The offline docs build prints about 8 warnings, all about the missing
charm pages; see [troubleshooting](troubleshooting.md).

If only the Go lines fail and you are on the CI or Python group, you can
still do your issue. Tell me what you saw.

## Checkpoint

- [ ] `~/microceph-workshop/clinic preflight` ends with a line starting `READY`
      (the last line; the host and environment sections above it each have
      their own `checks:` summary)

## If prep fails

If it is not in [troubleshooting](troubleshooting.md), send me the full
`prep.sh` output and `./clinic preflight` output.
