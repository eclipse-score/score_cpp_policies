# Sanitizers

Centralized sanitizer infrastructure for S-CORE C++ modules.

Each sanitizer (ASan, UBSan, LSan, TSan) is independently configurable via a
dedicated Bazel config flag. Sanitizers can be used in isolation or combined.

---

## Quick Start

```bash
# Run tests with AddressSanitizer
bazel test --config=asan //your/target/...

# Run tests with ThreadSanitizer
bazel test --config=tsan //your/target/...

# Run tests with the recommended CI combination (ASan + UBSan + LSan)
bazel test --config=asan_ubsan_lsan //your/target/...

# Run tests with TSan + UBSan
bazel test --config=tsan_ubsan //your/target/...
```

> **Note:** Import `sanitizers.bazelrc` from your workspace `.bazelrc` to make the
> above configs available:
> ```
> try-import %workspace%/path/to/score_cpp_policies/sanitizers/sanitizers.bazelrc
> ```

---

## Architecture

```
sanitizers/
├── sanitizers.bazelrc   # --config=asan/ubsan/lsan/tsan/asan_ubsan_lsan/tsan_ubsan
├── flags/               # bool_flag per sanitizer; config_setting_group for combinations
├── features/            # cc_feature per sanitizer (score_asan, score_ubsan, ...)
├── constraints/         # no_*/only_* target_compatible_with aliases
├── suppressions/        # Per-sanitizer suppression files (*.supp)
├── templates/           # Per-sanitizer runtime env-var templates
├── wrapper.sh           # Test runner: loads all active env files then exec "$@"
└── private/             # Internal Starlark helpers (expand_template, etc.)
```

### `flags/` — Build-time boolean flags

One `bool_flag` per sanitizer (`asan`, `ubsan`, `lsan`, `tsan`) and corresponding
`config_setting`s (`asan_on`, `ubsan_on`, ...). Composite groups:

| Group | Meaning |
|---|---|
| `any_sanitizer` | True if any of the four flags is set |
| `any_asan_ubsan_lsan` | True if ASan **or** UBSan **or** LSan is set |
| `asan_ubsan_lsan` | True only if **all three** of ASan, UBSan, LSan are set |

Flags are set automatically by the `--config=` aliases in `sanitizers.bazelrc`.
Do not set them directly unless you have a non-standard composition need.

### `features/` — Compiler/linker feature definitions

One `cc_feature` per sanitizer, registered under the `score_*` namespace to
avoid collisions with toolchain built-in feature names:

| Feature name | Sanitizer | Key flags |
|---|---|---|
| `score_asan` | AddressSanitizer | `-fsanitize=address` |
| `score_ubsan` | UndefinedBehaviorSanitizer | `-fsanitize=undefined`, `-fsanitize-link-c++-runtime`* |
| `score_lsan` | LeakSanitizer | `-fsanitize=leak` |
| `score_tsan` | ThreadSanitizer | `-fsanitize=thread`, `-O1` |
| `debug_symbols` | (shared) | `-g1` + `--strip=never` |

*`-fsanitize-link-c++-runtime` is Clang-only. It ensures the UBSan C++ runtime
library (`libclang_rt.ubsan_cxx`) is linked, which is required for C++ ABI
error handlers. GCC does not support this flag but also does not need it (GCC
links UBSan runtime automatically).

### `constraints/` — `target_compatible_with` aliases

Use these in `BUILD` files to skip tests that are incompatible with a sanitizer:

```python
cc_test(
    name = "my_test",
    # Skip under TSan — GoogleTest has known TSan false positives
    target_compatible_with = ["@score_cpp_policies//sanitizers/constraints:no_tsan"],
    ...
)

sh_test(
    name = "asan_violation_test",
    # Only run this test when ASan is active
    target_compatible_with = ["@score_cpp_policies//sanitizers/constraints:only_asan"],
    ...
)
```

Available constraints:

| Constraint | Meaning |
|---|---|
| `any_sanitizer` | Compatible only when at least one sanitizer is active |
| `no_asan` | Skip when ASan is active |
| `no_ubsan` | Skip when UBSan is active |
| `no_lsan` | Skip when LSan is active |
| `no_tsan` | Skip when TSan is active |
| `no_asan_ubsan_lsan` | Skip when any of ASan/UBSan/LSan is active (compatibility alias) |
| `only_asan` | Only run when ASan is active |
| `only_ubsan` | Only run when UBSan is active |
| `only_lsan` | Only run when LSan is active |
| `only_tsan` | Only run when TSan is active |

### `wrapper.sh` — Runtime environment loader

The test runner script. It is set via `--run_under` in `sanitizers.bazelrc`
and sources all `*_relative_sanitizer.env` files present in its directory.
Each env file sets sanitizer-specific runtime options (e.g. `ASAN_OPTIONS`,
`TSAN_OPTIONS`) and points to the corresponding suppression file.

---

## Toolchain Registration

To use sanitizer features, register them in your toolchain's `known_features`
or `extra_known_features`:

```python
# In MODULE.bazel
llvm.toolchain(
    llvm_version = "...",
    extra_known_features = [
        "@score_cpp_policies//sanitizers/features:debug_symbols",
        "@score_cpp_policies//sanitizers/features:asan",
        "@score_cpp_policies//sanitizers/features:ubsan",
        "@score_cpp_policies//sanitizers/features:lsan",
        "@score_cpp_policies//sanitizers/features:tsan",
    ],
)
```

---

## Suppression Files

Runtime suppression files live in `suppressions/`. Add suppressions for known
false positives in your module's `.bazelrc` or by passing the suppression file
path in the `*_OPTIONS` environment variable.
