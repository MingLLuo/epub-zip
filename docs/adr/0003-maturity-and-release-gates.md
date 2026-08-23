# ADR 0003: Maturity and release gates

- Status: Accepted
- Date: 2026-08-23

## Context

The first three releases established the native architecture, EPUB container rules, defensive
extraction, and bilingual interface. A successful happy-path build is not enough to call a
filesystem utility mature: its input-preservation promise, resource limits, batch behavior,
license notices, and distributed artifacts must also be testable invariants.

This decision defines the minimum gates for future public releases without expanding the product
into an EPUB editor or a full replacement for EPUBCheck.

## Decision

### Input and archive invariants

- An operation must never replace its input, even when the caller selects the replace policy.
- A destination that is the input, contains the input, or sits inside a packed source directory is
  rejected before any output is created.
- Inspection applies entry-count and path-length limits while iterating; limits must not be checked
  only after the complete central directory has been materialized.
- Inspection and extraction share path-topology checks. A file cannot also be a directory or be an
  ancestor of another entry.
- `container.xml` is parsed once by a shared strict OCF parser. The required namespace, element
  hierarchy, version, `full-path`, and OPF media type are errors rather than best-effort warnings.

### Product behavior

- A graphical batch keeps every item result, reports partial failures, and can reveal all completed
  outputs. New input is never acknowledged and then silently discarded while a batch is running.
- Long diagnostics remain readable in a resizable window, and decorative status imagery is hidden
  from assistive technologies.
- Language detection must not show Simplified Chinese for Traditional Chinese preferences; an
  unsupported language falls back to English.

### Release integrity

- `VERSION` is the release source of truth and an automated check guards unavoidable copies.
- Apple Silicon artifacts are built with an explicit `arm64` target and verified before packaging.
- Binary distributions include the project license and all required third-party notices.
- CI uses the same verification and packaging entry points as maintainers, exercises the example,
  and validates the application bundle rather than only its unbundled executable.
- Local builds may use an ad-hoc signature. A public build is considered production-ready only when
  it is Developer ID signed with hardened runtime, notarized, stapled, and Gatekeeper-verified.

## Release levels

| Level | Meaning |
|---|---|
| Development | Locally built, ad-hoc signed, suitable for source review and testing |
| Public beta | All automated gates pass; remaining limitations are documented |
| Production | Public beta gates plus Developer ID signing and successful Apple notarization |

The repository can automate all production preparation, but it cannot manufacture the maintainer's
Apple Developer identity or notarization credentials. A build without those credentials must remain
clearly described as ad-hoc signed.

The executable checklist and credential boundary are maintained in
[`docs/releasing.md`](../releasing.md); vulnerability support and residual risk are maintained in
[`SECURITY.md`](../../SECURITY.md).

## Consequences

- Core validation becomes stricter and may reject containers that older versions accepted even
  though they did not conform to the documented OCF boundary.
- Batch state and tests become slightly larger, but completed work and failures are no longer lost.
- Release scripts gain validation steps while keeping the application architecture and runtime
  dependency count unchanged.
- Full publication semantics, metadata editing, DRM handling, and format conversion remain outside
  the project scope.
