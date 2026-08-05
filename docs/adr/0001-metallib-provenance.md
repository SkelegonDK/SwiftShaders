# 0001 — `default.metallib` is generated and gitignored, not committed

**Status:** Accepted · **Date:** 2026-08-04 · **Phase:** 1 of `plans/00-shader-integrity-remediation.md`

## Context

SwiftPM's CLI build (`swift build` / `swift test`) has no build rule for `.metal`
files — `TargetSourcesBuilder.swift`'s `metal` rule appears only in
`xcbuildFileTypes`, not `builtinRules`. The library's shaders must therefore be
compiled by a separate step, `Scripts/build-shaders.sh`, into
`Sources/SwiftShaders/Resources/default.metallib`, reached at runtime through
`ShaderLibrary.bundle(.module)`.

At the start of this work, that file was present on disk but neither tracked by git
nor gitignored — `git ls-files` returned nothing for it and `git check-ignore`
exited 1. A fresh checkout had no metallib and no way to get one short of running
the build script by hand; CI never ran it either, so CI was building and testing a
package with no shader library at all.

## Decision

**Generate the metallib in CI; never commit it.** Added
`Sources/SwiftShaders/Resources/*.metallib` to `.gitignore`, and added a "Compile
Metal shaders" step to `.github/workflows/ci.yml` that runs before `swift build`.
`make clean` now also removes `*.metallib`, and `make build` regenerates it
unconditionally, so the local and CI paths agree.

## Consequences

- A bare `git clone` with no further steps does not produce a working `swift build`
  — `Bundle.module` is a symbol SwiftPM only synthesizes for a target with valid
  resources, so a missing metallib fails the build outright (confirmed by deleting
  it and rebuilding: `error: type 'Bundle' has no member 'module'`). Anyone building
  outside this repo's `Makefile`/CI must run `Scripts/build-shaders.sh` first. This
  is a real gap in the distribution story, further explored (and left open) in
  `docs/adr/0005-platform-distribution.md`.
- No binary diffs in git history for a 2.4 MB artifact that changes on every shader
  edit.
- The metallib cannot silently go stale relative to the `.metal` sources it was
  built from — there is nothing to go stale, since it is never checked in. (A
  parallel drift check still exists for the manifest, `shader-signatures.tsv`,
  which *is* committed — see `CONTEXT.md`'s "drift check" entry.)
- Declaring `shader-signatures.tsv` as a second package resource later (Phase 2)
  means a missing metallib today produces failing tests rather than a hard build
  error — a clearer signal, but it makes those tests load-bearing for catching a
  partial or truncated metallib that would otherwise build fine.

## Alternatives considered

| Option | Verdict | Why |
|---|---|---|
| Commit `default.metallib`, add a drift check against it | Rejected | Binary git churn on every shader edit; Phase 7d later confirmed only one platform's metallib can ever be produced from this target anyway, so there's no multi-platform argument for committing it either. |
| **Generate in CI, gitignore locally** | **Chosen** | No churn; CI is the single source of truth; the cost (bare clone needs one extra script run) is paid once per environment, not once per commit. |
