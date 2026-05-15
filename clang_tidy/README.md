# Clang-Tidy Integration

Centralized clang-tidy configuration and Bazel macros for Eclipse S-CORE C++ modules.

## What This Provides

- **`//clang_tidy:defs.bzl`** — `make_clang_tidy_aspect` / `make_clang_tidy_test` macros wrapping `aspect_rules_lint`
- **`clang_tidy/.clang-tidy`** — default S-CORE check set (conservative baseline, tailorable per module)

## Usage

### Add Dependency

```python
bazel_dep(name = "score_cpp_policies", version = "0.0.0")
bazel_dep(name = "toolchains_llvm", version = "1.5.0")
```

Set up `@llvm_toolchain` via the `llvm` extension (see `tests/MODULE.bazel` for an example).

### Add the Bazelrc Snippet

There is no importable `.bazelrc` from an external module — `%workspace%` resolves to the
consuming workspace, not to `@score_cpp_policies`. Copy these lines into your own `.bazelrc`
instead:

```bazelrc
test:clang-tidy --output_groups=+rules_lint_report
# Pin the LLVM toolchain for clang-tidy — adjust the target for your host arch:
test:clang-tidy --extra_toolchains=@llvm_toolchain//:cc-toolchain-x86_64-linux
test:clang-tidy --aspects=//tools/lint:linters.bzl%clang_tidy_aspect
```

> **Note**: The `--extra_toolchains` line hard-codes `x86_64-linux`. On AArch64 hosts (Apple
> Silicon CI runners, etc.) replace it with `cc-toolchain-aarch64-linux`.

### Create `tools/lint/linters.bzl`

```python
load("@score_cpp_policies//clang_tidy:defs.bzl", "make_clang_tidy_aspect", "make_clang_tidy_test")

clang_tidy_aspect = make_clang_tidy_aspect(
    # binary MUST be a Label literal here — string labels silently resolve to the wrong repo.
    binary = Label("@llvm_toolchain//:clang-tidy"),
    configs = [Label("//:.clang-tidy")],
)

clang_tidy_test = make_clang_tidy_test(aspect = clang_tidy_aspect)
```

### Add a `.clang-tidy` Config

Place a `.clang-tidy` at your repo root. Use
[`@score_cpp_policies//clang_tidy:.clang-tidy`](.clang-tidy) as the starting point.

> **Advisory checks**: The enabled checks (`cppcoreguidelines-*`, `modernize-*`, etc.) are
> advisory — only `clang-analyzer-*` is `WarningsAsErrors`. Module owners should tighten
> `WarningsAsErrors` incrementally as compliance improves.

### Run

```bash
# Lint all C++ targets
bazel test --config=clang-tidy //...
```

Reports are written to `bazel-out/.../rules_lint_report/` as text files.
