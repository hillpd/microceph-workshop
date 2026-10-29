# Group 2: #243 `microceph disk list` shows unsupported disks

https://github.com/canonical/microceph/issues/243

## The problem

In 2023 `microceph disk list` showed a QEMU CD-ROM,
`scsi-0QEMU_QEMU_CD-ROM_lxd_config` (368 KiB, type `cdrom`), under
"Available unpartitioned disks". MicroCeph cannot use it as an OSD.

The only maintainer comment (2024-01-31) says the 2 GiB size threshold
fixed it. The filter has changed a lot since then. Today
`FilterAvailableDisks` skips read-only devices, partitioned devices,
devices under `constants.MinOSDSize` (2 GiB), devices already configured
as OSDs, mounted devices and Ceph WAL/DB devices. There is no rule by
device type.

Decision: the issue is believed fixed. The task is to verify that on
main and pin it with a regression test, so it cannot come back silently.
If the verification fails, it becomes a fix.

## Where

- `microceph/common/storage.go:426` `FilterAvailableDisks`; the skips are
  at lines 450 (read-only), 456 (partitions) and 462 (size). Its doc
  comment at 419-425 does not mention the read-only rule.
  `GetDevicePath` at line 398.
- `microceph/constants/constants.go:11` `MinOSDSize`.
- Callers: `cmd/microceph/disk_list.go:188` (`disk list`) and
  `ceph/osd.go:1461`.
- Tests: `microceph/common/storage_test.go`, `TestFilterAvailableDisksExcludesReadOnly`
  at line 196 is the closest existing case.
- Device fields come from LXD's `api.ResourcesStorageDisk` (`Type`,
  `Size`, `ReadOnly`, `DeviceID`, `DevicePath`).
- CI gate: the `Checks` workflow, jobs `Run static checks` and `Run Unit tests`.

## First job

Feed `FilterAvailableDisks` the device from the issue, next to a normal
8 GiB disk, and see whether it comes back. Then work out which rule drops
it, and which rule would drop a read-only optical drive with a large disc
in it. `(cd microceph && go test -count=1 ./common/...)` runs the package.

## Definition of done

- [ ] A test in `common/storage_test.go` shows the #243 device and other
      CD-ROM shapes are excluded on main, one case per rule that does
      the excluding.
- [ ] Each case has been seen to fail when the rule it pins is removed
      from `storage.go` (and the rule put back).
- [ ] Green: `(cd microceph && go test -count=1 ./common/...)`,
      `(cd microceph && make check-unit)`, `(cd microceph && make check-static)`.
- [ ] PR open with the test.
- [ ] Comment on the issue with what you found and a close recommendation;
      I close it or ask a maintainer to.
- [ ] Commit title `test: <summary>` with `Fixes #243` if the test passes
      on main; if it fails, `fix: <summary>` with the code change and
      `Fixes #243`.

## Watch out

- `GetDevicePath` prefers `DeviceID`, then `DevicePath`, then `ID`; give
  fake disks a `DevicePath` so the mount and Ceph-device hooks get a sane
  string.
- Inject `IsMountedFunc` and `IsCephDeviceFunc` through `DiskFilterConfig`,
  or the test touches the real host.
- `storage_test.go` keeps its imports in two groups, older than the
  three-group house rule. Leave them.
- LXD sets `ReadOnly` from sysfs `ro`; an optical drive is not always
  marked read-only.
- `make check-unit` caches test results; use `go test -count=1`.
- Question: if a type rule turns out to be needed, which `Type` values
  does LXD actually set (`lxd/resources/storage.go`, or
  `lxc query /1.0/resources` on any LXD host)?
