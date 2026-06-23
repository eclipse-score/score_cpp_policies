# Coverage — adoption guide

Centralized C++ source-based coverage tooling for Eclipse S-CORE modules,
built on `llvm-cov` source-based coverage. This package provides:

| Component | What it does |
|---|---|
| `:merger` (py_binary) | Per-test profraw → profdata + object-file packaging. Wired as `--coverage_output_generator` by `coverage.bazelrc`. |
| `:reporter` (py_binary) | Final aggregation: profdata merge + llvm-cov HTML / LCOV / text. Invoked by the per-consumer wrapper produced by `score_coverage_reporter`. |
| `:justify` (py_binary) | Reads a YAML database + `COV_JUSTIFIED` source markers and emits a manifest of justified lines/branches. |
| `:effective_coverage` (py_binary) | Post-processes the llvm-cov HTML to highlight justified lines and compute effective coverage. |
| `:generate_coverage_html` (sh_binary) | One-shot driver: unzip Bazel coverage output, run justification, optional CI archive. |
| `defs.bzl :: score_coverage_reporter` | Macro consumers call to wire the report generator with their own filter regex extensions and llvm tools. |
| `coverage.bazelrc` | Generic `coverage` flags consumers import from their own `.bazelrc`. |
| `filter_regexes.txt` | Baseline `--ignore-filename-regex` set (tests, mocks, fakes, benchmarks, external/). |

---

## Prerequisites

Your repository must already have:

1. **A Bzlmod setup** (`MODULE.bazel`).
2. **An `@llvm_toolchain`-style toolchain registered** through
   `toolchains_llvm` (or any other source that produces `:llvm-cov` and
   `:llvm-profdata` targets). The repository name does *not* have to be
   `llvm_toolchain` — you pass the labels to the macro.
3. **A coverage-instrumented C++ toolchain** that matches the `@llvm_toolchain`
   above (set via `--extra_toolchains` in your `.bazelrc`).

---

## 1. Depend on `score_cpp_policies`

```python
# MODULE.bazel
bazel_dep(name = "score_cpp_policies", version = "<version>")
```

`rules_python`, `rules_shell` and the `pyyaml` pip hub are pulled in
transitively — you do **not** need to declare them yourself.

> ⚠️ Add one line to your **root** `BUILD` / `BUILD.bazel` so the macro can
> rlocation-resolve the consumer workspace root at runtime:
>
> ```python
> exports_files(["MODULE.bazel"])
> ```

## 2. Import the generic bazelrc

```bazelrc
# .bazelrc
import %workspace%/../external/+_repo_rules+score_cpp_policies/coverage/coverage.bazelrc
```

Or, more portably, vendor a one-line `coverage.bazelrc` in your repo:

```bazelrc
# .bazelrc
try-import %workspace%/coverage.bazelrc
```

```bazelrc
# coverage.bazelrc (vendored)
import %workspace%/external/+_repo_rules+score_cpp_policies/coverage/coverage.bazelrc
```

If your build uses a `local_path_override`, refer to the file by its repo
root path. (The recommended pattern is to copy the file's `import` lines
into your project's `.bazelrc` — there are no hidden flags.)

## 3. Set your instrumentation filter

`coverage.bazelrc` deliberately leaves `--instrumentation_filter` empty
because it is module-specific. Add one line in **your** `.bazelrc`:

```bazelrc
coverage --instrumentation_filter="^//<your_top_level_package>[/:]"
```

> 💡 Use `[/:]` (not just `/`) so the top-level package itself
> (e.g. `//mymod:lib`) is included, not just subpackages.

## 4. Create your reporter wrapper

Create a small BUILD file (e.g. `tools/coverage/BUILD.bazel`):

```python
load("@score_cpp_policies//coverage:defs.bzl", "score_coverage_reporter")

score_coverage_reporter(
    name = "reporter_wrapper",
    llvm_cov = "@llvm_toolchain//:llvm-cov",
    llvm_profdata = "@llvm_toolchain//:llvm-profdata",
    # OPTIONAL: extend the baseline ignore regexes with project-specific patterns.
    extra_regex_files = [":coverage_filter_regexes.txt"],
    visibility = ["//visibility:public"],
)

exports_files(["coverage_filter_regexes.txt"])
```

Example `tools/coverage/coverage_filter_regexes.txt`:

```text
# Project-specific exclusions on top of the S-CORE baseline.
.*/generated/.*
.*/proto/.*\.pb\.(h|cc)$
```

## 5. Point Bazel at your wrapper

```bazelrc
# .bazelrc
coverage --coverage_report_generator=//tools/coverage:reporter_wrapper
```

## 5a. (Optional) Surface untested files at 0% coverage

`llvm-cov` only reports source files that are linked into at least one
exercised test. Source files that ship in the project but no test pulls in
will silently disappear from the report — which usually misrepresents
coverage as higher than it actually is.

To surface those files at 0% coverage, build a manifest of every C/C++
source reachable from your coverage roots and pass it to the reporter:

```python
load(
    "@score_cpp_policies//coverage:defs.bzl",
    "score_coverage_reporter",
    "score_instrumented_sources_manifest",
)

score_instrumented_sources_manifest(
    name = "instrumented_sources",
    # The aspect walks `deps` (and `srcs`) recursively, so listing the
    # top-level library/binary/test targets is enough.
    targets = [
        "//mymod:lib",
        "//mymod/tests:all_tests",
    ],
)

score_coverage_reporter(
    name = "reporter_wrapper",
    llvm_cov = "@llvm_toolchain//:llvm-cov",
    llvm_profdata = "@llvm_toolchain//:llvm-profdata",
    extra_regex_files = [":coverage_filter_regexes.txt"],
    instrumented_sources_manifest = ":instrumented_sources",
    visibility = ["//visibility:public"],
)
```

Anything in the manifest that the llvm-cov export does not already cover
(and that survives the configured `--ignore-filename-regex` set) is added
as a synthetic 0%-coverage record to the LCOV file and gets a per-file
HTML page plus a "Not Linked Into Tests" section on the report index.

## 6. (Optional) Set up justifications

Create `tools/coverage/coverage_justifications.yaml`:

```yaml
version: 1
justifications:
  - id: hw-unreachable-on-x86
    category: platform_specific
    reason: |
      ARM-only error path; cannot be exercised by x86 CI.
    locations:
      - file: mymod/src/foo.cpp
        line_start: 42
        line_end: 47
```

Or annotate code in place:

```cpp
// One-liner:
return false;  // COV_JUSTIFIED hw-unreachable-on-x86

// Region:
// COV_JUSTIFIED_START hw-unreachable-on-x86
if (running_on_arm()) { ... }
// COV_JUSTIFIED_STOP
```

Valid categories: `defensive_programming`, `tool_false_positive`,
`platform_specific`, `other`. IDs must be kebab-case.

## 7. Run it

```bash
# Collect coverage data.
bazel coverage //... --build_tests_only

# Build the HTML report + run justifications (if YAML exists) + show summary.
bazel run @score_cpp_policies//coverage:generate_coverage_html -- \
    --yaml tools/coverage/coverage_justifications.yaml
```

The HTML report appears at `cpp_coverage/index.html` by default. The
human-readable summary shows raw vs. effective line/branch coverage.

For CI, you can also produce a zipped archive (HTML + LCOV + JUnit XMLs):

```bash
bazel run @score_cpp_policies//coverage:generate_coverage_html -- \
    --yaml tools/coverage/coverage_justifications.yaml \
    --archive coverage_artifacts
```

---

## Customization knobs

| Need | How |
|---|---|
| Add project-specific ignore regexes | `extra_regex_files = [":<file>"]` on the macro |
| Different llvm version | Register your own `@my_llvm` and pass `llvm_cov = "@my_llvm//:llvm-cov"` |
| Different output directory | `--output-dir <path>` on `generate_coverage_html` |
| Different effective coverage threshold | `COVERAGE_THRESHOLD=95 bazel run ...:generate_coverage_html ...` |

## Troubleshooting

- **`html_report/ not found`** — re-run `bazel coverage` first; the script
  only post-processes existing output.
- **Some `.cpp` files missing from the report** — confirm your
  `--instrumentation_filter` covers the top-level package using `[/:]`
  (not just `/`).
- **Test / mock files appearing in the report** — add a pattern that
  matches their path or filename to your `extra_regex_files` entry.
- **`llvm-cov not found in runfiles`** — the macro arg `llvm_cov` must
  point to a real binary target in your repo's repo mapping; the
  default `@llvm_toolchain//:llvm-cov` requires `use_repo(llvm, "llvm_toolchain")`.
