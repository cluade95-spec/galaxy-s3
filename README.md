# LineageOS 14.1 for Samsung GT-I8200 (goldenvess3g): feasibility project

Investigating whether Android 7.1.2 (LineageOS 14.1) can be brought to the Samsung Galaxy S III Mini Value Edition, **GT-I8200** (`goldenvess3g`, Marvell PXA986 board on the PXA988 kernel platform, Vivante GC1000).

Not to be confused with GT-I8200N / GT-I8200L (`goldenve3g`) or GT-I8190 (`golden`, a different chip). GT-I8200Q shares our codename.

## Status

| Phase | State |
|---|---|
| Milestone 1: feasibility report | Done: [docs/feasibility-report.md](docs/feasibility-report.md) |
| Phase 0: source verification | **Partly done:** [docs/phase-0-source-verification.md](docs/phase-0-source-verification.md) |
| Phase 1: study SM-T110 port | Not started (can start now) |
| Phases 2–5: kernel, build, hardware bring-up | Not started. No build has been run. Nothing has been tested on hardware. |

### Phase 0 key results
- **Best GT-I8200 kernel source found:** `Koloses/kernel_i8200` import commit `44afe4c` ("I8200XXUAOC1 kernel source"). Strong evidence it is Samsung's original package, built on a Samsung machine in Jan 2016. Not yet matched against Samsung's official download.
- **Gabrius99's goldenvess3g kernel is derived from the older GT-I8200N tree.** It won't be used as a base.
- **Firmware identity:** newest GT-I8200 build is I8200XXUAPB1 (Feb 2016). I8200XXUAOC1 (Mar 2015) matches the kernel source. All builds are Android 4.2.2. No firmware has been downloaded or checksummed yet.
- **NFC:** spec sheets say only the I8200N has NFC, but Samsung's kernel package was built with NFC enabled. Whether the phone has the chip is unconfirmed.
- **SM-T110 LineageOS 14.1 port:** the graphics compatibility patches look reusable. The project can't be rebuilt from its published files, and its hardware results are reported only by its owner.

### Open blockers
- `opensource.samsung.com` and Samsung firmware servers are blocked by this environment's network policy. That blocks the official kernel package and stock firmware checksums.
- Phone identity details are needed from the owner (model, baseband, build number, NFC toggle). Look only, change nothing.

**Safety rules:** nothing is flashed or written to the physical phone. Unverified ROMs are not downloaded. No feature is claimed to work without evidence.
