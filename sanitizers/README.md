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
>
> Or consume `SANITIZER_PRESETS` via [bazelrc-preset.bzl](https://github.com/bazel-contrib/bazelrc-preset.bzl) instead — see
> [Distribution via bazelrc-preset.bzl](#distribution-via-bazelrc-presetbzl) below.

---

## Distribution via bazelrc-preset.bzl

[bazelrc-preset.bzl](https://github.com/bazel-contrib/bazelrc-preset.bzl) generates a
`.bazelrc` fragment from `SANITIZER_PRESETS` that you vendor into your own repo,
instead of copy-pasting `sanitizers.bazelrc` by hand.

1. Add the dependency to your `MODULE.bazel`:
   ```python
   bazel_dep(name = "score_cpp_policies", version = "<version>")
   bazel_dep(name = "bazelrc-preset.bzl", version = "1.9.2")
   ```
2. Reference `SANITIZER_PRESETS` (or `PRESETS` for sanitizers + clang-tidy together)
   from a `BUILD` file, e.g. `tools/BUILD`:
   ```python
   load("@bazelrc-preset.bzl", "bazelrc_preset")
   load("@score_cpp_policies//:presets.bzl", "PRESETS")
   # Or, sanitizers only:
   # load("@score_cpp_policies//sanitizers:presets.bzl", "SANITIZER_PRESETS")

   bazelrc_preset(
       name = "preset",
       extra_presets = PRESETS,
   )
   ```
3. Generate and commit the preset file: `bazel run //tools:preset.update`.
4. Import it from your workspace `.bazelrc`:
   ```
   import %workspace%/tools/preset.bazelrc
   ```
5. `bazel test //tools:preset.update_test` catches drift whenever `presets.bzl`
   changes — re-run step 3 to update.

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
| `no_asan_ubsan_lsan` | Skip when **any** of ASan, UBSan, or LSan is active (see note below) |
| `only_asan` | Only run when ASan is active |
| `only_ubsan` | Only run when UBSan is active |
| `only_lsan` | Only run when LSan is active |
| `only_tsan` | Only run when TSan is active |

> **Note — `no_asan_ubsan_lsan` semantic:**  
> In the previous single-flag API, `no_asan_ubsan_lsan` was satisfied only when the
> combined `asan_ubsan_lsan` preset was active (i.e. all three flags simultaneously).
> In the current per-flag API it is satisfied when **any one** of the three flags is
> set, matching `any_asan_ubsan_lsan`:
>
> | Scenario | Old behaviour | New behaviour |
> |---|---|---|
> | Only `--//flags:asan=True` | Target **skipped** — combo not active, so `no_asan_ubsan_lsan` was always satisfied | Target **skipped** — `any_asan_ubsan_lsan` is satisfied |
> | `--//flags:asan + :ubsan + :lsan` | Target **skipped** | Target **skipped** |
> | No sanitizer | Target **built** | Target **built** |
>
> If you need the old "skip only when all three are active" behaviour, reference
> `//sanitizers/flags:asan_ubsan_lsan` (the `match_all` group) directly in a
> custom `config_setting`.

---

## Valid Sanitizer Combinations

The following table shows which flag combinations are **supported**:

| ASan | UBSan | LSan | TSan | Status | Preset |
|:---:|:---:|:---:|:---:|---|---|
| ✓ | | | | ✅ Supported | `--config=asan` |
| | ✓ | | | ✅ Supported | `--config=ubsan` |
| ✓ | | ✓ | | ✅ Supported | `--config=asan` + `--config=lsan` |
| ✓ | ✓ | ✓ | | ✅ Supported | `--config=asan_ubsan_lsan` (**recommended**) |
| | | | ✓ | ✅ Supported | `--config=tsan` |
| | ✓ | | ✓ | ✅ Supported | `--config=tsan_ubsan` |
| ✓ | | | ✓ | ❌ **Invalid** | ASan+TSan: incompatible runtime libraries |
| | | ✓ | ✓ | ❌ **Invalid** | LSan+TSan: TSan has built-in leak detection |

Invalid combinations are caught at **build time** by
`@score_cpp_policies//sanitizers/flags:sanitizer_combination_check` (the CI
test suite depends on this target automatically via `tests/BUILD.bazel`).

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

`@score_cpp_policies//sanitizers:suppressions` exposes all four files as a
`filegroup`, for consumers that need to package them alongside their own
repo-specific suppressions (e.g. into an OCI/Docker image for integration
testing) rather than relying on `wrapper` at test-run time.

---

## Migration from v0.x

The `--@score_cpp_policies//sanitizers/flags:sanitizer=<value>` string flag has been removed.
Replace any direct flag usage with the equivalent `--config=` alias:

| Old | New |
|-----|-----|
| `--@score_cpp_policies//sanitizers/flags:sanitizer=asan_ubsan_lsan` | `--config=asan_ubsan_lsan` |
| `--@score_cpp_policies//sanitizers/flags:sanitizer=tsan` | `--config=tsan` |

`--config=asan`, `--config=ubsan`, and `--config=lsan` now activate exactly their named
sanitizer rather than the combined `asan_ubsan_lsan` mode.

### GCC-specific feature variants removed

The `asan_ubsan_lsan_gcc` and `tsan_gcc` `cc_feature` targets (which omitted
`-fsanitize-link-c++-runtime`) have been removed. The new per-sanitizer features
(`score_asan`, `score_ubsan`, etc.) work with both Clang and GCC toolchains. If you were
registering GCC-specific features explicitly in your toolchain, replace them with the new
single features (e.g. `@score_cpp_policies//sanitizers/features:asan`).

### `no_asan_ubsan_lsan` constraint semantics changed

See the `constraints/` section above — in the previous
single-flag API, `no_asan_ubsan_lsan` was satisfied only when the combined
`asan_ubsan_lsan` preset was active (all three flags simultaneously). In the current
per-flag API it is satisfied when **any one** of the three flags is set. Prefer the more
granular `no_asan`, `no_ubsan`, or `no_lsan` constraints for new targets.
