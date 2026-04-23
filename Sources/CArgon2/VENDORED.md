# Vendored Sources

| Field | Value |
|---|---|
| Package | phc-winner-argon2 |
| Source | https://github.com/P-H-C/phc-winner-argon2 |
| Commit | f57e61e19229e23c4445b85494dbf7c07de721cb |
| Date | 2021-06-25 |
| Licence | CC0 1.0 Universal / Apache License 2.0 |
| Authors | Daniel Dinu, Dmitry Khovratovich, Jean-Philippe Aumasson, Samuel Neves |

## Files copied

| Local path | Upstream path |
|---|---|
| `include/argon2.h`          | `include/argon2.h`              |
| `argon2.c`                  | `src/argon2.c`                  |
| `core.c`                    | `src/core.c`                    |
| `core.h`                    | `src/core.h`                    |
| `encoding.c`                | `src/encoding.c`                |
| `encoding.h`                | `src/encoding.h`                |
| `ref.c`                     | `src/ref.c`                     |
| `thread.c`                  | `src/thread.c`                  |
| `thread.h`                  | `src/thread.h`                  |
| `blake2/blake2b.c`          | `src/blake2/blake2b.c`          |
| `blake2/blake2.h`           | `src/blake2/blake2.h`           |
| `blake2/blake2-impl.h`      | `src/blake2/blake2-impl.h`      |
| `blake2/blamka-round-ref.h` | `src/blake2/blamka-round-ref.h` |

No modifications were made to any copied file.

## Intentionally excluded

| Upstream path | Reason |
|---|---|
| `src/opt.c`                    | x86 SSE2-optimised implementation — cannot compile on arm64 |
| `src/blake2/blamka-round-opt.h`| Includes `<emmintrin.h>` (SSE2); causes `Module '_Builtin_intrinsics.intel.sse2' requires feature 'x86'` on arm64 |
| `src/bench.c`                  | Benchmarking tool, not library code |
| `src/run.c`                    | CLI tool, not library code |
| `src/test.c`                   | Upstream test harness, not library code |
| `src/genkat.c`                 | KAT generation tool, not library code |

## Validation

Output of `Argon2.hash` at any given parameters is byte-identical to
`argon2.low_level.hash_secret_raw` from Python's `argon2-cffi` library, because
both call the same reference C implementation at the same commit.

Cross-validated 2026-03-01 against `argon2-cffi==23.1.0` using the vectors in
`Tests/Argon2Tests/vectors.json`.

## Update procedure

To re-vendor a newer upstream commit:

1. Note the new commit SHA from https://github.com/P-H-C/phc-winner-argon2
2. Download the 13 files listed above at the new SHA
3. Verify no new files need to be excluded (check for new `*-opt*` or `*intrin*` headers)
4. Update this file with the new SHA and date
5. Run `swift test` and the iOS Simulator build to confirm no regressions
