# Publishing future CourtLine updates

The current bootstrap release is [Initial release](https://github.com/dswartzlander/Courtline/releases), with **Android v0.91** and **iPad v0.93**. It stays published.

## Unified versioning

Use **v1.0** as the first unified release. This is essential: the already-published Android v0.91 and iPad v0.93 update checkers only recognize `vMAJOR.MINOR` asset filenames. They will **not** find a `v1.0.0` package. Once v1.0 has been installed, we can upgrade the app parsers to accept three-part semantic versions for future releases.

Never reset Android's internal `versionCode` when switching the displayed version to 1.0. It must be greater than the previously installed build. Keep the iPad bundle/build identifiers valid and increment build versions when applicable.

## How to publish

1. Build and test **signed** Android APK and **Swift Playgrounds** ZIP. Keep signing keys and source repositories private.
2. Name the files `Courtline-Tablet-v1.0-Description.apk` and `Courtline-iPad-v1.0-Description.zip`. Keep the version the **same** for both platforms.
3. Stage the **distribution files only** under `updates/staging/v1.0/` in this repository, using Codex/Git (or another authorized Git client). This folder is public; **never put credentials or Android source archives containing a keystore here**.
4. Compute checksums for the **exact** staged files: `sha256sum Courtline-Tablet-*.apk Courtline-iPad-*.zip` (Windows PowerShell: `Get-FileHash -Algorithm SHA256 file`).
5. In GitHub, open **Actions → Publish CourtLine update → Run workflow**. Enter version `1.0`, the two filenames, and their individual 64-digit SHA-256 checksums.
6. GitHub Actions verifies filenames, content checksums, ZIP integrity, and the **existing Android signing certificate**, rejects duplicate release tags, then publishes a stable release `v1.0` with both files.
7. The existing CourtLine apps should discover new assets when the user presses **Check for Updates**. Android still prompts for install approval. iPad still requires importing the ZIP into Swift Playgrounds.

This workflow is **manual approval and publication**, not unattended app compilation: it does not know how to build an iPad Swift Playgrounds app or sign Android without private build materials. It does not stage binaries for you.

The public GitHub repo is for release distribution. Do not put the complete Android source ZIP, keystore, API tokens, helper connection URLs, or live event configurations here.
