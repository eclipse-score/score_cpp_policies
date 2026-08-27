# Migration: from toolchain-owned to policy-owned warnings

See [`warnings.md`](warnings.md) for the full feature/flag reference this
migration moves you to.

## Old model

Prior to this repo taking ownership, the warnings `cc_feature`s
(`minimal_warnings`, `strict_warnings`, `all_wall_warnings`) were defined
directly inside `score_bazel_cpp_toolchains` itself, hardcoded into each
toolchain release. `minimal_warnings` was enabled **by default**; the
stricter levels existed too, but were opt-in — consumers had to turn them
on themselves (e.g. via `--features=strict_warnings`) if they wanted them.
This meant:

- The flag *content* of every level wasn't customizable or independently
  versioned — you could choose which level to turn on, but not what flags
  each level contained, short of forking `score_bazel_cpp_toolchains`.
- Changing a flag required a change (and release) of
  `score_bazel_cpp_toolchains`, coupling warning-policy changes to
  toolchain/compiler-version changes.
- No single, audited, per-OS list of *which* flags were enabled and *why*.

## New model

Warning flags now live here, as versioned, opt-in `cc_feature` targets under
[`warnings/gcc/features/BUILD`](../warnings/gcc/features/BUILD):
`minimal_warnings`, `strict_warnings`, `all_wall_warnings` (each implying the
previous), and the independent `warnings_as_errors` toggle. `score_bazel_cpp_toolchains`
only recognizes the **name** `all_wall_warnings` as part of its contract (see
the comment in [`warnings/gcc/features/BUILD`](../warnings/gcc/features/BUILD));
the actual flags, per-OS differences, and documentation are owned and versioned here.

## Prerequisites

- `score_bazel_cpp_toolchains` **1.0.0 or newer**. Feature injection via
  `extra_known_features` / `extra_enabled_features` was already generally
  available before 1.0.0, but earlier versions also hardcoded their own
  warnings `cc_feature`s internally — injecting `score_cpp_policies`'
  warnings features with the same names over that external API would
  collide with those built-in ones and fail. Only in 1.0.0 were the
  hardcoded warnings features removed, so injecting these labels works
  without a conflict. If you're on an older version, upgrade it as part of
  this migration; there is no way to adopt `score_cpp_policies` warnings on
  an older toolchain version.
- `score_cpp_policies` **0.1.0 or newer** — the warnings features were
  introduced in `0.1.0`.

## What stays compatible

- Once you're on `score_bazel_cpp_toolchains` >= 1.0.0, future warning-flag
  changes only require bumping `score_cpp_policies` — no further toolchain
  version bump needed for that.
- Existing `cc_toolchain` registrations, target platforms, and other
  toolchain features (sanitizers, debug symbols, etc.) are unaffected.
- If you never referenced GCC warning flags through the toolchain directly
  (e.g. you rely only on your own project-level `copts`) and don't plan to
  adopt these features, no action is required.

## Required changes

1. Bump `score_bazel_cpp_toolchains` to **1.0.0 or newer** (see
   [Prerequisites](#prerequisites) above).
2. Add `score_cpp_policies` (>= `0.1.0`) as a `bazel_dep` (if not already
   present, e.g. for sanitizers/clang-tidy).
3. Register the feature labels you want available via `extra_known_features`
   on your `gcc.toolchain(...)` extension call, and — if they should be on
   by default for all consumers of that toolchain — also add them to
   `extra_enabled_features`:

   ```starlark
   gcc = use_extension("@score_bazel_cpp_toolchains//extensions:gcc.bzl", "gcc")
   gcc.toolchain(
       ...
       extra_known_features = [
           "@score_cpp_policies//warnings/gcc/features:minimal_warnings",
           "@score_cpp_policies//warnings/gcc/features:strict_warnings",
           "@score_cpp_policies//warnings/gcc/features:all_wall_warnings",
           "@score_cpp_policies//warnings/gcc/features:warnings_as_errors",
       ],
   )
   ```

4. Remove any equivalent `-W...` flags you previously added yourself (e.g.
   via `copts`, a custom `cc_feature`, or a fork of
   `score_bazel_cpp_toolchains`) to avoid duplicate/conflicting flags.
5. Pick a starting severity level per module and enable it explicitly with
   `--features=minimal_warnings` (or `strict_warnings` / `all_wall_warnings`)
   — nothing is auto-enabled just because it's now a known feature, **not
   even `minimal_warnings`**, which used to be on by default before this
   migration; add it to `extra_enabled_features` (or `--features=`) if you
   still want it on unconditionally.
6. Expect new build failures: `strict_warnings` and `all_wall_warnings` catch
   real, previously-unflagged issues (conversions, shadowing, unused code,
   etc.). Roll out level-by-level, fixing violations before raising the bar,
   and keep `warnings_as_errors` off until a level is clean.

## Example: minimal rollout for an existing module

```starlark
# MODULE.bazel
bazel_dep(name = "score_cpp_policies", version = "0.1.0")
bazel_dep(name = "score_bazel_cpp_toolchains", version = "1.0.2")

gcc = use_extension("@score_bazel_cpp_toolchains//extensions:gcc.bzl", "gcc")
gcc.toolchain(
    name = "my_module_gcc_toolchain",
    extra_known_features = [
        "@score_cpp_policies//warnings/gcc/features:minimal_warnings",
        "@score_cpp_policies//warnings/gcc/features:strict_warnings",
        "@score_cpp_policies//warnings/gcc/features:all_wall_warnings",
        "@score_cpp_policies//warnings/gcc/features:warnings_as_errors",
    ],
    extra_enabled_features = [
        "@score_cpp_policies//warnings/gcc/features:minimal_warnings",
    ],
    ...
)
```

```bash
# .bazelrc
build:strict_warnings --features=strict_warnings
build:strict_warnings_ci --config=strict_warnings --features=warnings_as_errors
```
