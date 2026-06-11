# score_cpp_policies

Centralized C++ quality tool policies for Eclipse S-CORE, providing sanitizer
configurations and clang-tidy integration reusable across all S-CORE modules
(logging, communication, baselibs, etc.).

Planned: clang-format, code coverage policies.

## What This Provides

- **Sanitizer Bazel feature flags** — ASan, UBSan, LSan, TSan as Bazel build features
- **`//sanitizers:wrapper`** — shell script that sets all sanitizer runtime options centrally
- **`sanitizers/sanitizers.bazelrc`** — canonical config that consumers import or copy
- **Suppression files** — per-sanitizer suppression lists for known false positives (GoogleTest, etc.)
- **Constraint system** — `target_compatible_with` settings for sanitizer-incompatible targets
- **`clang_tidy/.clang-tidy`** — centralized default check set (conservative baseline, tailorable per module)
- **`clang_tidy/clang_tidy.bazelrc`** — `--config=clang-tidy` bazelrc config consumers can import

## Available Sanitizer Configurations

| Config | Sanitizers | Notes |
|--------|-----------|-------|
| `--config=asan` | AddressSanitizer | Memory errors, buffer overflows |
| `--config=ubsan` | UndefinedBehaviorSanitizer | Integer overflow, null deref |
| `--config=lsan` | LeakSanitizer | Memory leaks |
| `--config=tsan` | ThreadSanitizer | Data races, deadlocks — cannot combine with ASan/LSan |
| `--config=asan_ubsan_lsan` | ASan + UBSan + LSan | **Recommended default for CI** |
| `--config=tsan_ubsan` | TSan + UBSan | Threading + undefined behavior |

## Sanitizer Combination Compatibility

| Combination | Valid? | Notes |
|---|---|---|
| ASan + UBSan | ✅ Yes | Standard — included in `--config=asan_ubsan_lsan` |
| ASan + LSan | ✅ Yes | Included in `--config=asan_ubsan_lsan` |
| TSan + UBSan | ✅ Yes | Use `--config=tsan_ubsan` |
| ASan + TSan | ❌ No | Incompatible runtime libraries (`libasan` vs `libtsan`) |
| LSan + TSan | ❌ No | TSan has built-in leak detection; enabling both causes runtime conflicts |

Invalid combinations are enforced at the **compiler level** — Clang emits an explicit error (e.g.
`error: invalid argument '-fsanitize=address' combined with '-fsanitize=thread'`).
The `//sanitizers/flags:sanitizer_combination_check` target additionally catches these at Bazel
build time when included in the build graph (the CI test suite depends on it automatically).

## Usage

### Add Dependency

```python
bazel_dep(name = "score_cpp_policies")
```

### Configure Sanitizers

Copy [`sanitizers/sanitizers.bazelrc`](sanitizers/sanitizers.bazelrc) into your repository's `.bazelrc`.

### Run Tests

```bash
# ASan + UBSan + LSan (recommended)
bazel test --config=asan_ubsan_lsan //...

# ThreadSanitizer (separate run — cannot combine with ASan)
bazel test --config=tsan //...
```

## Tagging Tests for Sanitizer Compatibility

```python
cc_test(
    name = "my_test",
    srcs = ["my_test.cpp"],
    tags = ["no-tsan"],  # skip when running --config=tsan
    deps = ["@googletest//:gtest_main"],
)
```

| Tag | Skipped when using |
|-----|--------------------|
| `no-tsan` | `--config=tsan` |
| `no-asan` | `--config=asan` or `asan_ubsan_lsan` |
| `no-lsan` | `--config=lsan` or `asan_ubsan_lsan` |
| `no-ubsan` | `--config=ubsan` or `asan_ubsan_lsan` |

## Suppression Files

Default suppressions for common third-party libraries are included:

| File | Sanitizer | Current Suppressions |
|------|-----------|---------------------|
| `sanitizers/suppressions/asan.supp` | ASan | *(empty)* |
| `sanitizers/suppressions/lsan.supp` | LSan | GoogleTest static initialization leaks |
| `sanitizers/suppressions/tsan.supp` | TSan | stdlib false positives, Rust test suppressions |
| `sanitizers/suppressions/ubsan.supp` | UBSan | *(empty)* |

**Adding project-specific suppressions:** Currently, the wrapper loads suppressions from this module only. For project-specific suppressions, you'll need to create a custom wrapper or extend the environment variables in your `.bazelrc`. This is a known limitation being tracked for future improvements.

> **Runtime Options**: See [`sanitizers/templates/`](sanitizers/templates/) for detailed documentation of all sanitizer options configured by the wrapper.

## Constraint System

Use constraints to mark targets as incompatible with specific sanitizers:

```python
cc_library(
    name = "legacy_lib",
    target_compatible_with = [
        "@score_cpp_policies//sanitizers/constraints:no_tsan",
    ],
)
```

| Constraint | Effect |
|-----------|--------|
| `@score_cpp_policies//sanitizers/constraints:no_tsan` | Skip when `--config=tsan` |
| `@score_cpp_policies//sanitizers/constraints:no_asan_ubsan_lsan` | Skip when `--config=asan_ubsan_lsan` |
| `@score_cpp_policies//sanitizers/constraints:any_sanitizer` | Only builds with a sanitizer enabled |

## Testing This Repository

```bash
cd tests

bazel test --config=asan_ubsan_lsan //...
bazel test --config=tsan //...
bazel test --config=clang-tidy //...
```

## Migration from v0.x

The `--@score_cpp_policies//sanitizers/flags:sanitizer=<value>` string flag has been removed.
Replace any direct flag usage with the equivalent `--config=` alias:

| Old | New |
|-----|-----|
| `--@score_cpp_policies//sanitizers/flags:sanitizer=asan_ubsan_lsan` | `--config=asan_ubsan_lsan` |
| `--@score_cpp_policies//sanitizers/flags:sanitizer=tsan` | `--config=tsan` |

`--config=asan`, `--config=ubsan`, and `--config=lsan` now activate exactly their named sanitizer rather than the combined `asan_ubsan_lsan` mode.

### GCC-specific feature variants removed

The `asan_ubsan_lsan_gcc` and `tsan_gcc` `cc_feature` targets (which omitted `-fsanitize-link-c++-runtime`)
have been removed. The new per-sanitizer features (`score_asan`, `score_ubsan`, etc.) work with both Clang
and GCC toolchains. If you were registering GCC-specific features explicitly in your toolchain, replace them
with the new single features (e.g. `@score_cpp_policies//sanitizers/features:asan`).

### `no_asan_ubsan_lsan` constraint retained as compatibility alias

`//sanitizers/constraints:no_asan_ubsan_lsan` is kept as a backwards-compatible alias. It resolves to
`incompatible` if **any** of ASan, UBSan, or LSan is active. Prefer the more granular `no_asan`, `no_ubsan`,
or `no_lsan` constraints for new targets.

## Contributing

See [CONTRIBUTION.md](CONTRIBUTION.md) for guidelines. All commits must follow [Eclipse Foundation commit rules](https://www.eclipse.org/projects/handbook/#resources-commit). Contributors must sign the ECA and DCO.

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
