# MILESTONE

## 0.1.0 — Public Distribution

Status: **COMPLETE**

### Versioning

- [x] Semantic Versioning.
- [x] Initial public version `0.1.0`.
- [x] `VERSION` sebagai repository version source of truth.
- [x] `march-env --version`.
- [x] `march-env -v`.
- [x] `march-env version`.
- [x] Installer version validation.
- [x] Branch/tag resolve ke immutable commit SHA sebelum binary download.
- [x] Version drift acceptance test.

### Core CLI

- [x] `list`
- [x] `has`
- [x] `set`
- [x] direct positional value untuk `set`
- [x] `set-many`
- [x] `unset`
- [x] `unset-many`
- [x] `copy`
- [x] `copy-many`
- [x] `restart`
- [x] `--restart`
- [x] `--no-restart`
- [x] preservasi environment non-target
- [x] secret-safe output
- [x] CageFS compatibility tanpa ketergantungan `/dev/fd`

### Public Installation

- [x] Repository public.
- [x] HTTPS clone tanpa deploy key.
- [x] `install.sh` public installer.
- [x] Default install ke `~/.local/bin/march-env`.
- [x] Bash syntax validation sebelum replace.
- [x] Atomic binary replacement.
- [x] `MARCH_ENV_REF` untuk pin commit/tag.
- [x] `MARCH_ENV_INSTALL_DIR` untuk custom install path.
- [x] README public installation/update documentation.
- [x] Installer isolation: hanya menulis `march-env` pada install directory.
- [x] Tidak mengedit `~/.bashrc` atau konfigurasi tool lain.
- [x] Acceptance test memastikan `marchjson` tidak dihapus, ditimpa, atau diubah saat install/reinstall.

### Runtime Acceptance

- [x] CloudLinux Node.js Selector discovery.
- [x] Single set/unset write path.
- [x] Batch set/unset write path.
- [x] Copy/copy-many no-op path.
- [x] Explicit restart.
- [x] Health/readiness tetap normal setelah perubahan tervalidasi.
- [ ] Copy actual-write akan divalidasi ketika ada target nyata yang membutuhkan copy, tanpa memodifikasi credential hanya untuk test.

## Distribution

Canonical repository:

```text
https://github.com/MarchTechnology/march-env
```

Quick install:

```bash
curl -fsSL \
  -H 'Accept: application/vnd.github.raw+json' \
  -H 'User-Agent: march-env-installer' \
  'https://api.github.com/repos/MarchTechnology/march-env/contents/install.sh?ref=main' |
  bash
```

Public Git installation:

```bash
git clone https://github.com/MarchTechnology/march-env.git
```
