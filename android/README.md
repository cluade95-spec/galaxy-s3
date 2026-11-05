# Android build inputs (SKELETON, not buildable)

This directory holds the **device tree skeleton** for the Samsung **GT-I8200** (`goldenvess3g`) targeting
LineageOS 14.1 (Android 7.1.2). It is meant to be copied into a LineageOS 14.1 source tree.

**It is not buildable yet and must not be flashed.** Required information is missing (stock boot image header, real
partition table and sizes, official firmware, verified vendor files). Every gap is marked `TODO(...)`. Nothing here has
been compiled, built into an image or run on a phone.

Layout:

| Path | Contents |
|---|---|
| `device/samsung/goldenvess3g/` | Device configuration only. No proprietary binaries. |
| `vendor/samsung/goldenvess3g/` | Vendor manifest and a guarded extraction tool. **Contains no blobs.** Blobs may only be extracted from verified official firmware. |
| `../docs/phase-4-device-tree-skeleton.md` | What is ready, incomplete, blocked or unsupported, and why. |
| `../docs/phase-4-cellular-investigation.md` | Whether the Marvell RIL can realistically be adapted. |

Status labels used in comments: **VERIFIED** (checked in source/binary evidence), **DERIVED** (follows from verified
facts), **CLAIMED** (community source, unverified), **DECISION** (a project choice, not a hardware fact),
**TODO** (unknown; deliberately not guessed).
