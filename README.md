# score_cpp_policies

Centralized C++ quality tool policies for Eclipse S-CORE, providing sanitizer
configurations and clang-tidy integration reusable across all S-CORE modules
(logging, communication, baselibs, etc.).

Planned: clang-format, code coverage policies.

## What This Provides

- **[`sanitizers/`](sanitizers/README.md)** — ASan/UBSan/LSan/TSan Bazel `cc_feature`s, ready-to-use `--config=` aliases, suppression files, and `target_compatible_with` constraints.
- **[`clang_tidy/`](clang_tidy/README.md)** — centralized `.clang-tidy` baseline (conservative, tailorable per module) and a `--config=clang-tidy` Bazel integration.

## Sanitizers

ASan, UBSan, LSan, and TSan as independently configurable Bazel `cc_feature`s, with
ready-to-use `--config=` aliases (`asan`, `ubsan`, `lsan`, `tsan`, `asan_ubsan_lsan`,
`tsan_ubsan`), suppression files for known false positives, and `target_compatible_with`
constraints for skipping or restricting tests under specific sanitizers.

```bash
bazel test --config=asan_ubsan_lsan //...   # recommended default for CI
```

See [`sanitizers/README.md`](sanitizers/README.md) for setup, the full config/constraint
reference, and the v0.x migration guide.

## Clang-Tidy

Centralized `.clang-tidy` check set and a `--config=clang-tidy` Bazel integration via
`aspect_rules_lint`.

See [`clang_tidy/README.md`](clang_tidy/README.md) for the 8-step setup guide.

## Testing This Repository

```bash
cd tests

bazel test --config=asan_ubsan_lsan //...
bazel test --config=tsan //...
bazel test --config=clang-tidy //...
```

## Contributing

See [CONTRIBUTION.md](CONTRIBUTION.md) for guidelines. All commits must follow [Eclipse Foundation commit rules](https://www.eclipse.org/projects/handbook/#resources-commit). Contributors must sign the ECA and DCO.

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
