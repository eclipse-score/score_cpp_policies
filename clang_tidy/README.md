# Clang-Tidy Integration

Centralized clang-tidy configuration and Bazel macros for Eclipse S-CORE C++ modules.

## What This Provides

- **`//clang_tidy:defs.bzl`** — `make_clang_tidy_aspect` / `make_clang_tidy_test` macros wrapping `aspect_rules_lint`
- **`clang_tidy/.clang-tidy`** — default S-CORE check set (conservative baseline, tailorable per module)
- **`clang_tidy/clang_tidy.bazelrc`** — canonical bazelrc snippet consumers import

## Usage

### Add Dependency

```python
bazel_dep(name = "score_cpp_policies", version = "0.0.0")
bazel_dep(name = "toolchains_llvm", version = "1.5.0")
```

Set up `@llvm_toolchain` via the `llvm` extension (see `tests/MODULE.bazel` for an example).

### Import the Bazelrc Snippet

In your `.bazelrc`:

```bazelrc
import %workspace%/path/to/clang_tidy.bazelrc
test:clang-tidy --aspects=//tools/lint:linters.bzl%clang_tidy_aspect
```

### Create `tools/lint/linters.bzl`

```python
load("@score_cpp_policies//clang_tidy:defs.bzl", "make_clang_tidy_aspect", "make_clang_tidy_test")

clang_tidy_aspect = make_clang_tidy_aspect(
    binary = Label("@llvm_toolchain//:clang-tidy"),
    configs = [Label("//:.clang-tidy")],
)

clang_tidy_test = make_clang_tidy_test(aspect = clang_tidy_aspect)
```

### Add a `.clang-tidy` Config

Place a `.clang-tidy` at your repo root. Use
[`@score_cpp_policies//clang_tidy:.clang-tidy`](.clang-tidy) as the starting point.

### Run

```bash
# Lint all C++ targets
bazel test --config=clang-tidy //...
```

Reports are written to `bazel-out/.../rules_lint_report/` as text files.
