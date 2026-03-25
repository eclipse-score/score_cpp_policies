# Sanitizers

Centralized sanitizer configurations and Bazel feature flags for Eclipse S-CORE C++ modules.

## What This Provides

- **Sanitizer Bazel feature flags** — ASan, UBSan, LSan, TSan as Bazel build features
- **`//sanitizers:wrapper`** — shell script that sets all sanitizer runtime options centrally
- **`sanitizers/sanitizers.bazelrc`** — canonical config that consumers import or copy
- **Suppression files** — per-sanitizer suppression lists for known false positives (GoogleTest, etc.)
- **Constraint system** — `target_compatible_with` settings for sanitizer-incompatible targets

## Available Sanitizer Configurations

| Config | Sanitizers | Notes |
|--------|-----------|-------|
| `--config=asan_ubsan_lsan` | ASan + UBSan + LSan | **Recommended** — catches memory errors, UB, and leaks |
| `--config=asan` | AddressSanitizer | Alias for `asan_ubsan_lsan` |
| `--config=ubsan` | UndefinedBehaviorSanitizer | Alias for `asan_ubsan_lsan` |
| `--config=lsan` | LeakSanitizer | Alias for `asan_ubsan_lsan` |
| `--config=tsan` | ThreadSanitizer | Cannot be combined with ASan |

## Usage

### Add Dependency

```python
bazel_dep(name = "score_cpp_policies", version = "0.0.0")
```

### Configure Sanitizers

Copy the sanitizer configs from `sanitizers/sanitizers.bazelrc` into your `.bazelrc` and adapt the paths:

```bazelrc
# ASan + UBSan + LSan (Combined)
build:asan_ubsan_lsan --features=asan
build:asan_ubsan_lsan --features=ubsan
build:asan_ubsan_lsan --features=lsan
build:asan_ubsan_lsan --platform_suffix=asan_ubsan_lsan
test:asan_ubsan_lsan --config=with_debug_symbols
test:asan_ubsan_lsan --test_tag_filters=-no-asan,-no-lsan,-no-ubsan
test:asan_ubsan_lsan --@score_cpp_policies//sanitizers/flags:sanitizer=asan_ubsan_lsan
test:asan_ubsan_lsan --run_under=@score_cpp_policies//sanitizers:wrapper

# Shortcuts
build:asan  --config=asan_ubsan_lsan
test:asan  --test_tag_filters=-no-asan
build:ubsan --config=asan_ubsan_lsan
test:ubsan --test_tag_filters=-no-ubsan
build:lsan  --config=asan_ubsan_lsan
test:lsan  --test_tag_filters=-no-lsan

# ThreadSanitizer
build:tsan --features=tsan
build:tsan --platform_suffix=tsan
test:tsan --config=with_debug_symbols
test:tsan --cxxopt=-O1
test:tsan --test_tag_filters=-no-tsan
test:tsan --@score_cpp_policies//sanitizers/flags:sanitizer=tsan
test:tsan --run_under=@score_cpp_policies//sanitizers:wrapper
```

> **Note**: The `--run_under=@score_cpp_policies//sanitizers:wrapper` automatically loads runtime
> options and suppressions from the module.

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

**Adding project-specific suppressions:** Currently, the wrapper loads suppressions from this
module only. For project-specific suppressions, you'll need to create a custom wrapper or extend
the environment variables in your `.bazelrc`. This is a known limitation being tracked for future
improvements.

> **Runtime Options**: See [`templates/`](templates/) for detailed documentation of all sanitizer
> options configured by the wrapper.

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
