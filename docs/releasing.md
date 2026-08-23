# Release guide

This guide separates a reproducible local build from a trusted public macOS release. It implements
the gates accepted in [ADR 0003](adr/0003-maturity-and-release-gates.md).

## Release levels

| Level | Required evidence | Suitable use |
|---|---|---|
| Development | Tests pass; app is ad-hoc signed | Local source review and testing |
| Public beta | Automated gates and artifact inspection pass; limitations are documented | Evaluation by informed testers |
| Production | Public beta plus Developer ID, Hardened Runtime, notarization, stapling, and Gatekeeper assessment | General public distribution |

The repository can automate preparation and verification, but it cannot provide a maintainer's
Apple Developer identity or notarization credentials. Never describe the default `make app` output
as production-signed.

## Prerequisites

- Apple Silicon Mac running macOS 13 or later
- Xcode 16 or later and matching command-line tools
- clean Git worktree at the intended release commit
- for production: an active Apple Developer membership, a **Developer ID Application**
  certificate in the keychain, and a `notarytool` keychain profile

Keep certificate material, app-specific passwords, API keys, and notarization profiles out of the
repository and shell history. Use the macOS keychain, following Apple's
[notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## 1. Prepare the version

`VERSION` is the source of truth. Update it together with the unavoidable runtime and bundle
copies, add the matching `CHANGELOG.md` entry, and remove stale artifact names from both READMEs.
`make verify` guards runtime/bundle copies and required resources; README and changelog accuracy
remain an explicit review item.

Before building:

```bash
git status --short
make format
make lint
make test
make example
make verify
```

Review the complete diff. Important design changes should already have an ADR and a distinct Git
commit; a release commit should not conceal unrelated source changes.

## 2. Build and inspect a local candidate

```bash
make build
make app
make verify-artifacts
```

By default this creates explicit `arm64` artifacts under `dist/`, including:

```text
EPUB Zip-<version>-arm64-development.dmg
EPUB Zip-<version>-arm64-development.zip
epubzip-<version>-arm64-cli-development.zip
MinimalBook.epub
```

At this point the app is ad-hoc signed and remains a **development candidate**. Artifact checks must
confirm:

- the app and CLI executables are `arm64` (or exactly the architectures intentionally requested);
- bundle and CLI versions equal `VERSION`;
- `Info.plist`, `AppIcon.icns`, and `PrivacyInfo.xcprivacy` are present and readable;
- app and CLI packages contain `LICENSE` and `THIRD_PARTY_NOTICES.md`;
- the packaged CLI reports the expected `epubzip <version>`;
- the example EPUB has first, stored, extra-field-free `mimetype` and passes `epubzip check`.

An optional universal app is built explicitly:

```bash
ARCHS="arm64 x86_64" make app
```

Do not silently replace the default Apple Silicon artifact with a different architecture set.

## 3. Create a production-signed candidate

Select the exact certificate identity shown by `security find-identity -v -p codesigning`, then
rebuild:

```bash
CODESIGN_IDENTITY="Developer ID Application: Publisher Name (TEAMID)" make build
CODESIGN_IDENTITY="Developer ID Application: Publisher Name (TEAMID)" make app
CODESIGN_IDENTITY="Developer ID Application: Publisher Name (TEAMID)" make verify-artifacts
```

When a non-ad-hoc identity is supplied, the release build must enable Hardened Runtime and a secure
timestamp. Verify the application extracted from the distribution before notarization:

```bash
codesign --verify --deep --strict --verbose=2 "EPUB Zip.app"
codesign --display --verbose=4 "EPUB Zip.app"
```

The displayed authority must be the intended Developer ID identity and the runtime flag must be
present. A successful `codesign --verify` alone does not prove notarization.

The signing-aware CLI build signs its executable before packaging. It remains labeled
`signed-not-notarized`; do not call that archive a production download until it completes an
applicable Apple notarization workflow.

## 4. Notarize and staple the DMG

Create a named keychain profile once, outside the repository:

```bash
xcrun notarytool store-credentials "epubzip-notary"
```

Then submit the signed DMG through the project helper:

```bash
NOTARYTOOL_PROFILE="epubzip-notary" \
  Scripts/notarize.sh "dist/EPUB Zip-<version>-arm64-signed-not-notarized.dmg"
```

The helper must wait for an **Accepted** result, staple the ticket, validate the staple, and run a
Gatekeeper assessment. A rejected, invalid, timed-out, or unstapled candidate is not releasable.
Archive the notarization submission identifier in private maintainer records; do not publish
credentials.

The DMG is the primary production artifact. Do not advertise the app ZIP as notarized unless its
contained app has independently completed the applicable notarization and stapling workflow.

## 5. Checksums and publication

Generate SHA-256 checksums only after the final signed/notarized bytes will no longer change:

```bash
make checksums
make verify-checksums
```

`Scripts/create-checksums.sh` includes every current-version ZIP/DMG and `MinimalBook.epub` found
in its target directory. Before running it for a public release, deliberately separate development
and `signed-not-notarized` intermediates from the files intended for publication. Keep the
intermediates privately until downloaded-artifact verification succeeds; do not accidentally
publish them because they share the release version.

Review every entry in `dist/SHA256SUMS` before publishing. Every listed file must be uploaded
together, or the checksum file should be regenerated from the actual publication set. The release
tag must be `v<VERSION>` and
point to the exact tested commit. Release notes should:

- summarize user-visible and security changes from `CHANGELOG.md`;
- state the minimum macOS version and included architectures;
- identify the DMG as Developer ID signed and notarized only when the gate passed;
- label any ad-hoc or unsigned artifact as development/public beta;
- link the security policy and EPUBCheck validation boundary;
- publish `SHA256SUMS` with the artifacts.

Do not replace files under an existing tag without changing the version. If bytes must change,
withdraw the candidate and create a patch release so checksums and audit history remain meaningful.

## 6. Clean-machine verification

Before announcing production:

1. download the published DMG and checksum rather than using the local copy;
2. verify the SHA-256 digest;
3. validate the stapled ticket and Gatekeeper assessment;
4. install the app from the DMG on a clean supported Apple Silicon account;
5. pack, check, and unpack `Examples/MinimalBook`;
6. test an existing-output conflict, a mixed-success batch, English, and Simplified Chinese;
7. confirm long errors remain readable and Finder reveals every successful batch output;
8. confirm the CLI package contains its licenses and reports the release version.

CI is a release prerequisite, not a substitute for this downloaded-artifact test. A GitHub-hosted
runner also does not confer Developer ID identity unless a separately reviewed secrets-based
signing workflow is configured.

## Release checklist

- [ ] `VERSION`, runtime version, bundle metadata, READMEs, and changelog agree.
- [ ] Formatting, lint, all tests, the example, and `make verify` pass.
- [ ] Dependency lock and third-party notice name ZIPFoundation 0.9.20.
- [ ] App icon and privacy manifest are packaged.
- [ ] App and CLI packages contain both license files.
- [ ] Architectures match the artifact names.
- [ ] No Finder metadata, caches, credentials, or unrelated directories are included.
- [ ] Production app is Developer ID signed with Hardened Runtime and timestamp.
- [ ] Notarization is Accepted; ticket is stapled and validated.
- [ ] Gatekeeper accepts the installed app.
- [ ] Final SHA-256 checksums match downloaded artifacts.
- [ ] Tag, commit, artifacts, and release notes are immutable and mutually consistent.

## Security release handling

For a vulnerability, coordinate disclosure under [`SECURITY.md`](../SECURITY.md). Add a regression
test before publication, prepare the fixed supported minor/patch release privately, and disclose
only after signed and notarized replacement artifacts are available. If an existing release is
unsafe, remove it from recommended downloads without deleting its Git history or reusing its tag.

## Reproducibility statement

EPUB Zip makes generated EPUB containers deterministic for identical supported source trees.
macOS application binaries, signatures, notarization tickets, ZIP distributions, and DMGs are not
claimed to be bit-for-bit reproducible across Xcode/SDK versions or signing times. Release
traceability therefore relies on the tagged source commit, recorded toolchain, code-signing
identity, notarization result, and published SHA-256 checksums.
