# vendor/samsung/goldenvess3g - manifest and guarded extraction (NO BLOBS)

**This directory contains no proprietary files and must stay that way.** Blobs are git-ignored.

Rules:

1. Files may only be extracted from **verified official GT-I8200 firmware** (exact model `GT-I8200`, codename
   `goldenvess3g`), unpacked offline. The route for obtaining and checking such firmware is in
   `docs/phase-2-preparation.md`. A community mirror is not proof of origin.
2. The existing rooted community dump (`Gabrius99/proprietary_vendor_samsung_goldenvess3g`) is **not** a source: it contains
   root tools, Android 4.2 platform files and unknown-version files. It was used only to *audit structure*.
3. `extract-files.sh` enforces this: it refuses without a provenance file, refuses rooted trees, refuses a wrong model
   (including GT-I8200N, GT-I8200Q, GT-I8200L, GT-I8190) and writes a report with SHA-256 of every file.

Files:

| File | Purpose |
|---|---|
| `proprietary-files.txt` | Proposed manifest (names and risk flags only). Status per line: extract, `#DEFER` or `#EXCLUDE`. |
| `extract-files.sh` | Guarded extraction from an unpacked firmware directory. Not run: no verified firmware exists yet. |
| `generate-vendor-mk.py` | Builds `goldenvess3g-vendor.mk` and `BoardConfigVendor.mk` from the manifest and what was extracted. |

Usage (when verified firmware exists):

```sh
export GOLDEN_FW_DIR=/path/to/unpacked/firmware     # contains system/ and PROVENANCE.txt
./extract-files.sh
python3 generate-vendor-mk.py
```

`PROVENANCE.txt` must contain `source=`, `package_name=`, `package_size=`, `package_sha256=` and a line
`origin=samsung-fus` or `origin=samsung-opensource` (how it was obtained and checked). The script cannot verify these
claims; it makes them explicit and records them.
