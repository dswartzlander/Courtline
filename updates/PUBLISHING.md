# CourtLine update publishing

CourtLine official downloads live in [GitHub Releases](https://github.com/dswartzlander/Courtline/releases).

## Initial unified release

The legacy bootstrap release includes Android v0.91 and iPad v0.93. The first unified release is **v1.0**, not v1.0.0, because those bootstrap update checkers only recognize two-part versions. From v1.0 onward, the app update checkers recognize both two-part versions (1.0) and three-part versions (1.0.1, 1.1.0).

**Android:** preserve package name `com.cerberus.courtline`, signing certificate, and monotonic `versionCode` (v1.0 uses 100). Each installed Android update needs the same certificate and a higher `versionCode`.

**iPad:** the updater downloads the Swift Playgrounds ZIP, but users must import/run the updated project manually. TestFlight remains optional.

## Publishing future releases

1. Build, test and approve one signed Android APK and one iPad Swift Playgrounds ZIP. Use matching version identifiers, e.g. `Courtline-Tablet-v1.0.1-Fixes.apk` and `Courtline-iPad-v1.0.1-Fixes.zip`.
2. Stage the exact **distribution binaries**, not source archives, in `updates/staging/v1.0.1/`. This repository and its staged assets are public.
3. Calculate a SHA-256 digest for each staged artifact and verify the bytes and Android signing certificate.
4. Update `updates/release-queue.json` on the `main` branch with the new version, exact filenames, SHA-256 hashes and `"approved": true`. **Committing this file is the release approval** and automatically triggers the `Publish CourtLine update` GitHub Actions workflow.
5. The workflow checks the approval, filenames, versions, both hashes, ZIP integrity and the original Android signing certificate. It refuses to replace a release tag that already exists.
6. If GitHub Actions is temporarily disabled or the automatic run does not appear, use **Actions → Publish CourtLine update → Run workflow** to retry with the same approved queue file. Confirm the run succeeds before announcing publication.
7. Once GitHub's published **stable** release contains the assets, users on Android and iPad can press **Updates** to discover them. Android still requires system installation approval; Swift Playgrounds still requires manual import.

The GitHub release queue contains only public file names, hashes, versions and a publish approval. The Android signing key, source code, helper addresses, credentials and user/event configurations must **never** be published in this repository.
