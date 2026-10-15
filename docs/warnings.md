# Compiler Warnings

Centralized warning `cc_feature`s for S-CORE C++ modules:

- **GCC** warnings, grouped into three cumulative severity levels plus a
  separate opt-in toggle that turns warnings into build errors (see
  [Feature levels](#feature-levels)).
- **MISRA C++:2023** Guideline Enforcement Plan (GEP) warnings, available for
  both **Clang** and **GCC** (see [`misra_cpp_2023`](#misra_cpp_2023)).

## Architecture

```
warnings/
├── clang/
│   └── features/
│       └── misra_cpp_2023/ # cc_feature: misra_cpp_2023_warnings (Clang GEP flags)
└── gcc/
    ├── features/         # Public cc_feature entry points
    │   ├── BUILD          #   minimal_warnings, strict_warnings, all_wall_warnings, warnings_as_errors
    │   └── misra_cpp_2023/ # cc_feature: misra_cpp_2023_warnings (GCC GEP flags)
    ├── args/             # cc_args_list combining the per-OS arg targets below
    └── args/{linux,qnx}/ # Actual -W flag lists (differ per OS due to GCC version/platform quirks)
```

Each feature is split internally into three `cc_args` targets so the right
flags are only applied to the right compile action:

| Suffix | Applies to |
|---|---|
| `_warnings_args` | All compile actions (C and C++) |
| `_c_warnings_args` | C compile actions only |
| `_cxx_warnings_args` | C++ compile actions only |

## Feature levels

The three severity features **imply** each other, so enabling a higher level
automatically enables everything below it:

```
all_wall_warnings → implies → strict_warnings → implies → minimal_warnings
```

| Feature | Meaning |
|---|---|
| `minimal_warnings` | Baseline warnings with a low false-positive rate; still opt-in — see [Enabling these features](#enabling-these-features). |
| `strict_warnings` | Adds conversion/shadowing/pedantic-style checks with a higher chance of firing on existing code. |
| `all_wall_warnings` | Adds the remaining GCC diagnostics not covered above (most already implied by `-Wall`/`-Wextra`, listed explicitly here for auditability). |
| `warnings_as_errors` | Independent toggle: escalates every enabled warning above to a hard compile error via `-Werror`. |

> **Linux vs. QNX:** The flag sets differ slightly between the two GCC
> toolchains — QNX's older GCC has known false positives on some checks
> (worked around with `-Wno-error=...`) and groups a few checks under a
> different level than Linux. Each table below is per-OS where the sets
> diverge.

## Enabling these features

These `cc_feature` targets are external to `score_bazel_cpp_toolchains`, so
upgrading the toolchain version alone does **not** make them available.
Consumers must also inject the feature labels into the toolchain module
extension via `extra_known_features` (to make a feature selectable) and,
if it should be on by default, `extra_enabled_features` as well:

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

Without this step, none of `minimal_warnings`, `strict_warnings`,
`all_wall_warnings`, or `warnings_as_errors` exist in the toolchain, so
enabling them via `--features=...` or a target's `features` attribute has
no effect.

---

## `minimal_warnings`

### Linux

**Common (C and C++):**

| Flag | What it does |
|---|---|
| `-Wall` | Enables GCC's standard baseline set of commonly useful warnings (unused values, obvious uninitialized use, suspicious control flow, etc.). |
| `-Wcast-align` | Warn when a pointer cast increases the required alignment of the target type (e.g. `char*` → `int*`), which can cause undefined behavior on strict-alignment architectures. |
| `-Wcast-qual` | Warn when a cast removes a type qualifier from a pointer, e.g. casting away `const` or `volatile`. |
| `-Wformat-nonliteral` | Warn if a `printf`/`scanf`-family format string is not a string literal and therefore cannot be checked against its arguments. |
| `-Wformat-signedness` | Warn about a signedness mismatch between a format conversion (e.g. `%d` vs `%u`) and the argument's type. |
| `-Wformat=2` | Enables the stricter format-string checks (a superset of the default `-Wformat`) for `printf`/`scanf`/`strftime`-style functions. |
| `-Wmissing-format-attribute` | Warn about `printf`-like functions that are missing a `format` attribute, so misuse of their arguments can't be caught by the compiler. |
| `-Wpointer-arith` | Warn about pointer arithmetic on `void*` or function pointers, a GNU extension whose element size is not well-defined by the standard. |
| `-Wredundant-decls` | Warn if something is declared more than once in the same scope, even when the declarations are identical. |
| `-Wreturn-local-addr` | Warn about returning the address of a local variable, parameter, or temporary — the returned pointer/reference dangles once the function returns. |
| `-Wsizeof-array-argument` | Warn when `sizeof` is applied to an array-typed function parameter, which has already decayed to a pointer. |
| `-Wundef` | Warn when a non-macro identifier is evaluated inside `#if` (it silently evaluates to `0`, which is rarely intended). |
| `-Wwrite-strings` | Give string literals the type `const char[]`, so assigning one to a non-`const char*` triggers a discarded-qualifier warning. |

**C only:**

| Flag | What it does |
|---|---|
| `-Wbad-function-cast` | Warn when the result of a function call is cast to a non-matching type (e.g. an `int`-returning function cast to a pointer type). |
| `-Wmissing-prototypes` | Warn if a global function is defined without a preceding prototype, so callers can't have their arguments checked against it. |

**C++ only:**

| Flag | What it does |
|---|---|
| `-Wodr` | Warn about One-Definition-Rule violations detected by GCC's type-merging (e.g. the same class defined differently across translation units), primarily under LTO. |
| `-Wreorder` | Warn when a constructor's member-initializer list is written in a different order than the members are declared — they are always initialized in declaration order regardless of the list's order. |

### QNX

**Common (C and C++):**

| Flag | What it does |
|---|---|
| `-Wall` | Same as on Linux — GCC's standard baseline warning set. |
| `-Wno-error=deprecated-declarations` | Keep deprecated-symbol usage a warning (never a hard error) even when `-Werror` is active elsewhere. |
| `-Wno-error=cpp` | Prevent `#warning` preprocessor directives from being escalated to errors under `-Werror`. |
| `-Wno-format-y2k` | Suppress the "format could produce a 2-digit year" check that's otherwise part of `-Wformat=2`'s `strftime` checks. |
| `-Wno-free-nonheap-object` | Suppress the "freeing a pointer not allocated on the heap" warning — worked around here due to a known false positive on this QNX GCC version. |
| `-Wno-maybe-uninitialized` | Disable `-Wmaybe-uninitialized` due to a GCC 8/9 bug producing false positives ([GCC PR 80635](https://gcc.gnu.org/bugzilla/show_bug.cgi?id=80635)); real cases are still caught by `-Wuninitialized` (part of `-Wall`) and the UB sanitizers. |
| `-Wunused-but-set-parameter` | Warn about a function parameter that is assigned a value but never subsequently read. |

**C only:** none.

**C++ only:**

| Flag | What it does |
|---|---|
| `-Wno-literal-suffix` | Suppress the warning about user-defined literal suffixes that don't start with an underscore (the standard reserves un-prefixed suffixes) — needed for compatibility with existing QNX headers/macros. |
| `-Wno-noexcept-type` | Suppress the C++17 warning about a function's `noexcept` specifier becoming part of its mangled type. |

---

## `strict_warnings`

### Linux

**Common (C and C++):**

| Flag | What it does |
|---|---|
| `-Wbool-compare` | Warn about comparisons between a boolean expression and an integer other than 0/1, or relational (`<`, `>=`, ...) comparisons between two boolean expressions. |
| `-Wconversion` | Warn about implicit conversions likely to change a value, such as narrowing an integer/float to a smaller type or converting between signed and unsigned. |
| `-Wdouble-promotion` | Warn when a `float` is implicitly promoted to `double`, which can silently happen in expressions and calls at a precision/performance cost. |
| `-Wextra` | Enables GCC's second common warning bundle (beyond `-Wall`): unused parameters, missing field initializers, sign-compare, and more. |
| `-Winvalid-pch` | Warn if a precompiled header exists for an included header but cannot be used. |
| `-Wlogical-not-parentheses` | Warn about `!` applied to the left operand of a comparison (e.g. `!x == y`), which usually indicates a missing pair of parentheses. |
| `-Wlogical-op` | Warn about suspicious uses of `&&`/`||` — e.g. where a bitwise operator was likely intended, or both operands are identical. |
| `-Wpedantic` | Warn about GNU extensions and other constructs forbidden by strict ISO C/C++, per the active `-std=` mode. |
| `-Wswitch-bool` | Warn when a `switch` statement's controlling expression has `bool` type, since only two values are ever meaningful. |
| `-Wunused-but-set-parameter` | Warn about a function parameter that is assigned a value but never subsequently read. |
| `-Wvla` | Warn whenever a variable-length array is used; VLAs risk unbounded stack growth and are disallowed by most safety-critical coding guidelines. |

**C only:** none.

**C++ only:**

| Flag | What it does |
|---|---|
| `-Wnarrowing` | Warn when a brace-enclosed initializer list (`{...}`) contains a narrowing conversion, which is ill-formed in standard C++11 and later. |

### QNX

**Common (C and C++):**

| Flag | What it does |
|---|---|
| `-Wextra` | Same as Linux — GCC's second common warning bundle. |
| `-pedantic` | Equivalent to `-Wpedantic` — enforce strict ISO C/C++ conformance diagnostics. |
| `-Warray-bounds=2` | Out-of-bounds array access detection at the more thorough level (beyond what a plain `-O1`-equivalent analysis catches). |
| `-Wcast-align` | See `minimal_warnings` (Linux) above — same meaning; grouped under `strict` on QNX instead. |
| `-Wcast-qual` | See `minimal_warnings` (Linux) above. |
| `-Wdisabled-optimization` | Warn when a requested optimization pass couldn't be performed, typically because the code is too large or complex. |
| `-Wfloat-conversion` | Warn about implicit conversions that reduce the precision of a floating-point value (the floating-point subset of `-Wconversion`). |
| `-Wformat=2` | See `minimal_warnings` (Linux) above. |
| `-Wimplicit-fallthrough=4` | Warn about `switch` cases that fall through without an explicit `break`, at the strictest level — only specially-formatted fallthrough comments are recognized as intentional. |
| `-Winvalid-pch` | See Linux above. |
| `-Wmissing-format-attribute` | See `minimal_warnings` (Linux) above. |
| `-Wmultichar` | Warn if a multi-character constant like `'ab'` is used; its value is implementation-defined. |
| `-Wpacked` | Warn about a `packed` attribute that has no effect, or a derived class that isn't packed while its base is. |
| `-Wscalar-storage-order` | Warn about scalar-member accesses whose result depends on the storage (endianness) order of a packed struct. |
| `-Wsuggest-attribute=format` | Suggest adding a `printf`/`scanf`-style `format` attribute to functions that look like they need one, so calls to them can be format-checked. |
| `-Wundef` | See `minimal_warnings` (Linux) above. |
| `-Wunused-macros` | Warn about macros defined in the main file that are never used. |
| `-Wvector-operation-performance` | Warn when a vector operation is emulated with scalar instructions because the target lacks native support, which may hurt performance. |
| `-Wwrite-strings` | See `minimal_warnings` (Linux) above. |
| `-Wformat-security` | Warn about `printf`/`scanf`-family calls where the format string isn't a literal and there are no arguments — a common format-string vulnerability pattern. |
| `-Wlogical-op` | See Linux above. |
| `-Wredundant-decls` | See `minimal_warnings` (Linux) above. |
| `-Wshadow` | Warn whenever a local variable, parameter, or type shadows another one of the same name from an outer scope. |
| `-Wconversion` | See Linux above. |
| `-Wsign-conversion` | Warn about implicit conversions between signed and unsigned integers that may change the value's sign or magnitude. |

**C only:**

| Flag | What it does |
|---|---|
| `-Wold-style-definition` | Warn if a function is defined in old-style K&R form (parameter names without types) instead of an ANSI/ISO prototype. |
| `-Wstrict-prototypes` | Warn if a function is declared or defined without argument types, e.g. `int f()` instead of `int f(void)`. |

**C++ only:**

| Flag | What it does |
|---|---|
| `-Wdelete-non-virtual-dtor` | Warn when `delete` is used on a pointer-to-base-class whose destructor isn't `virtual`, so derived-class members never get destroyed. |
| `-Woverloaded-virtual` | Warn when a derived-class function hides (instead of overriding) a base-class virtual function due to a signature mismatch. |
| `-Wregister` | Warn about the deprecated `register` storage-class specifier. |
| `-Wstrict-null-sentinel` | Warn about an un-cast `NULL` used as the sentinel argument to a variadic function, since `NULL` may not have the required pointer size/type. |

---

## `all_wall_warnings`

The remaining diagnostics not already covered by `minimal_warnings` /
`strict_warnings`. The common-flag list is nearly identical on Linux and
QNX — QNX omits `-Wmaybe-uninitialized` for the same reason noted under
`minimal_warnings` above.

**Common (C and C++):**

| Flag | What it does |
|---|---|
| `-Waddress` | Warn about suspicious address use, e.g. comparing the address of a function/array against `NULL` (always false/true). |
| `-Warray-bounds=1` | Detect out-of-bounds array accesses determinable without expensive analysis (the default checking level). |
| `-Warray-compare` | Warn about comparing two arrays with `==`/`!=`, which compares their addresses rather than their contents. |
| `-Warray-parameter=2` | Warn about mismatched array size/qualifiers for the same function parameter across redeclarations, at the strictest level. |
| `-Wbool-operation` | Warn about suspicious operations on `bool` values, e.g. bitwise negation. |
| `-Wchar-subscripts` | Warn when an array subscript has type `char`, which may be signed and yield a negative (out-of-range) index. |
| `-Wcomment` | Warn about a `/*` nested inside a `/* */` comment, or a `//` comment continued across lines via a trailing backslash. |
| `-Wdangling-else` | Warn about an `else` that indentation suggests belongs to a different `if` than the one it actually binds to. |
| `-Wdangling-pointer=2` | Warn (thorough level) when a stored pointer will refer to a variable/temporary after its lifetime has ended. |
| `-Wduplicate-decl-specifier` | Warn about a duplicated declaration specifier, e.g. `const const int x`. |
| `-Wenum-compare` | Warn about comparisons between values of two different enumerated types. |
| `-Wformat-contains-nul` | Warn if a format string contains an embedded NUL byte, which truncates the format at that point. |
| `-Wformat-diag` | Warn about format issues in strings passed to GCC's own diagnostic-formatting functions. |
| `-Wformat-extra-args` | Warn about excess arguments passed to a `printf`/`scanf`-style function beyond what its format string requires. |
| `-Wformat-overflow=1` | Warn (default level) about `sprintf`/`snprintf`-family calls whose output could overflow the destination buffer. |
| `-Wformat-truncation=1` | Warn (default level) about `snprintf`-family calls whose output may be silently truncated. |
| `-Wformat-zero-length` | Warn about calling a `printf`/`scanf`-family function with a zero-length format string. |
| `-Wframe-address` | Warn about `__builtin_frame_address`/`__builtin_return_address` called with a nonzero argument, which is unlikely to work as intended. |
| `-Winfinite-recursion` | Warn about a function call that can be statically determined to recurse indefinitely. |
| `-Winit-self` | Warn about a variable initialized with itself, e.g. `int i = i;` (usually a typo). |
| `-Wint-in-bool-context` | Warn about a suspicious integer expression (e.g. a left shift) used in a boolean context. |
| `-Wmain` | Warn if the declared type of `main` doesn't match the standard-required signature. |
| `-Wmaybe-uninitialized` | *(Linux only)* Warn about a variable that may be used uninitialized on some code path, per control-flow analysis. Disabled on QNX — see `minimal_warnings` notes above. |
| `-Wmemset-elt-size` | Warn when `memset`'s size argument looks like an element count rather than a byte count for arrays of non-1-byte elements. |
| `-Wmemset-transposed-args` | Warn about `memset` calls where the fill value and length arguments appear to be swapped. |
| `-Wmisleading-indentation` | Warn about code whose indentation suggests a different block structure than the braces actually produce. |
| `-Wmismatched-dealloc` | Warn about a pointer allocated with one function (e.g. `malloc`) being freed with a mismatched one (e.g. `delete`), or freed twice. |
| `-Wmissing-attributes` | Warn when a redeclaration or alias is missing attributes present on the original declaration that could affect codegen or correctness. |
| `-Wmissing-braces` | Warn about aggregate initializers missing braces around a nested array/struct sub-initializer. |
| `-Wmultistatement-macros` | Warn about a multi-statement macro used unbraced in a context (like an unbraced `if`) where only the first statement is actually controlled. |
| `-Wnonnull` | Warn about passing a null pointer to a parameter declared with the `nonnull` attribute. |
| `-Wnonnull-compare` | Warn about comparing a `nonnull`-declared argument against `NULL`, since the compiler may assume that comparison is always false. |
| `-Wopenmp-simd` | Warn if an OpenMP `simd` pragma is ignored due to a preceding `#pragma GCC optimize` or similar. |
| `-Wpacked-not-aligned` | Warn if a `packed` struct field doesn't have the alignment its type would naturally require. |
| `-Wparentheses` | Warn about likely-missing parentheses, e.g. mixing `&&`/`||` without grouping, or using assignment as a truth value. |
| `-Wrestrict` | Warn about overlapping arguments passed to a function/parameter declared `restrict`, which forbids aliasing. |
| `-Wreturn-type` | Warn about a non-`void` function with a code path lacking a `return`, or a `void` function returning a value. |
| `-Wsequence-point` | Warn about code with unspecified side-effect evaluation order that can change the result (sequencing undefined behavior). |
| `-Wsign-compare` | Warn about comparisons between signed and unsigned values that could produce an unexpected result. |
| `-Wsizeof-array-div` | Warn when dividing `sizeof` an array by the size of something other than that array's element type — a common element-count bug. |
| `-Wsizeof-pointer-div` | Warn when a division of two `sizeof` expressions looks like an element-count computation but one operand is actually a pointer's size. |
| `-Wsizeof-pointer-memaccess` | Warn about `memset`/`memcpy`-family calls whose size argument is `sizeof` a pointer rather than the pointed-to buffer. |
| `-Wstrict-aliasing` | Warn about code that likely violates C/C++ strict-aliasing rules, which can cause miscompilation under optimization. |
| `-Wstrict-overflow=1` | Warn (least aggressive level) about optimizations that assume signed overflow never occurs and could change program behavior. |
| `-Wswitch` | Warn when a `switch` on an `enum` doesn't handle all enumerators and has no `default`. |
| `-Wtautological-compare` | Warn about comparisons that are always true or false due to the operand types' limited range, e.g. `unsigned < 0`. |
| `-Wtrigraphs` | Warn about trigraphs that might change the meaning of the program. |
| `-Wuninitialized` | Warn about variables used before being initialized on some code path. |
| `-Wunknown-pragmas` | Warn about `#pragma` directives that GCC doesn't recognize. |
| `-Wunused` | Meta-flag enabling the common `-Wunused-*` checks (unused variables, labels, values, functions, etc.). |
| `-Wunused-but-set-variable` | Warn about a local variable assigned a value but never subsequently read. |
| `-Wunused-const-variable=1` | Warn about unused `const` variables at file scope (for variables used within the current translation unit). |
| `-Wunused-function` | Warn about a `static` function that is declared but never defined, or defined but never used. |
| `-Wunused-label` | Warn about a label that is declared but never used. |
| `-Wunused-local-typedefs` | Warn about a `typedef` declared locally but never used. |
| `-Wunused-value` | Warn about an expression statement whose computed value is discarded with no side effect. |
| `-Wunused-variable` | Warn about a local or file-scope variable that is declared but never used. |
| `-Wuse-after-free=2` | Warn (thorough level) about using a pointer after the memory it refers to has been freed. |
| `-Wvolatile-register-var` | Warn about a variable declared both `volatile` and `register`, a combination with unclear semantics. |
| `-Wzero-length-bounds` | Warn about accesses past the end of a zero-length array member that isn't the struct's last member (i.e. not a flexible-array-member idiom). |

**C only:**

| Flag | What it does |
|---|---|
| `-Wimplicit` | Meta-flag enabling `-Wimplicit-int` and `-Wimplicit-function-declaration`. |
| `-Wimplicit-function-declaration` | Warn when a function is called before being declared (implicitly assumed to return `int`); disallowed outright in C99 and later. |
| `-Wimplicit-int` | Warn when a declaration omits a type and implicitly defaults to `int`. |
| `-Wpointer-sign` | Warn about pointer assignments/initializations between pointee types differing only in signedness, e.g. `char*` vs `unsigned char*`. |
| `-Wvla-parameter` | Warn about mismatched variable-length-array parameter bounds between a function's declaration and its definition. |

**C++ only (Linux):**

| Flag | What it does |
|---|---|
| `-Waligned-new` | Warn when allocating an over-aligned type with `new` but the translation unit wasn't compiled with C++17 aligned-`new` support. |
| `-Wc++11-compat` | Warn about constructs whose meaning changes, or that become unavailable, between C++11 and later standards. |
| `-Wc++14-compat` | Same, for C++14. |
| `-Wc++17-compat` | Same, for C++17. |
| `-Wc++20-compat` | Same, for C++20. |
| `-Wcatch-value` | Warn about a `catch` clause catching a polymorphic type by value instead of by reference, which slices the object. |
| `-Wclass-memaccess` | Warn about calling `memset`/`memcpy` on a non-trivial class type, which can bypass constructors/destructors and corrupt vtables. |
| `-Wdelete-non-virtual-dtor` | See `strict_warnings` (QNX) above — same meaning, grouped under `all` on Linux. |
| `-Wmismatched-new-delete` | Warn when memory allocated with `new` is freed with a mismatched `delete`/`free`, or vice versa. |
| `-Woverloaded-virtual` | See `strict_warnings` (QNX) above — same meaning, grouped under `all` on Linux. |
| `-Wpessimizing-move` | Warn about a `std::move` that actually defeats copy elision, or a move that's redundant because the source is already an rvalue. |
| `-Wrange-loop-construct` | Warn about a range-based `for` loop copying an element each iteration where a reference would avoid it, or binding a temporary to a reference in a way that risks dangling. |
| `-Wuseless-cast` | Warn about a cast to the same type the expression already has. |

**C++ only (QNX):** same list as Linux, minus `-Wdelete-non-virtual-dtor` and
`-Woverloaded-virtual`, which QNX already enables under `strict_warnings`.

---

## `warnings_as_errors`

Independent of the severity levels above; escalates whatever is currently
enabled to a hard compile error.

| Flag | Platform | What it does |
|---|---|---|
| `-Werror` | Linux & QNX | Turn every currently-enabled warning into a compile error, so a build cannot succeed while warnings remain. |
| `-Wno-error=deprecated-declarations` | Linux only | Exempt deprecated-declaration warnings from the `-Werror` escalation above — deprecations are advisory and shouldn't block a build. |

---

## `misra_cpp_2023`

Compiler warnings mapped to the [MISRA C++:2023 Guideline Enforcement Plan (GEP)](https://github.com/eclipse-score/communication/blob/main/quality/static_analysis/misra_gep.md),
which lists which MISRA rules/directives can be covered by compiler
diagnostics instead of a separate static analysis tool. Unlike the GCC
severity levels above, this is a single, non-cumulative feature per
toolchain — it does not imply and is not implied by `minimal_warnings`,
`strict_warnings`, or `all_wall_warnings`.

Both toolchain variants expose the same public feature name,
`misra_cpp_2023_warnings`, but live at different labels and carry a
different, toolchain-specific flag set (Clang and GCC diagnose different
subsets of the GEP with different flag names):

| Toolchain | Target |
|---|---|
| Clang | `@score_cpp_policies//warnings/clang/features/misra_cpp_2023:misra_cpp_2023` |
| GCC | `@score_cpp_policies//warnings/gcc/features/misra_cpp_2023:misra_cpp_2023` |

### Enabling this feature

As with the GCC severity levels, this `cc_feature` is external to
`score_bazel_cpp_toolchains` and must be injected into the toolchain module
extension via `extra_known_features` (and `extra_enabled_features` if it
should be on by default):

```starlark
# Clang
llvm = use_extension("@toolchains_llvm//toolchain/extensions:llvm.bzl", "llvm")
llvm.toolchain(
    extra_known_features = [
        "@score_cpp_policies//warnings/clang/features/misra_cpp_2023:misra_cpp_2023",
    ],
    ...
)

# GCC
gcc = use_extension("@score_bazel_cpp_toolchains//extensions:gcc.bzl", "gcc")
gcc.toolchain(
    extra_known_features = [
        "@score_cpp_policies//warnings/gcc/features/misra_cpp_2023:misra_cpp_2023",
    ],
    ...
)
```

Then enable it via `--features=misra_cpp_2023_warnings` or a target's
`features` attribute. It is not composed with `warnings_as_errors` — pair it
with that feature yourself if violations should fail the build.

### Clang flags

| Flag | What it does |
|---|---|
| `-Wunreachable-code` | Warn about code that can never be executed, e.g. statements after an unconditional `return`/`break`/`continue`/`throw`. |
| `-Wunreachable-code-return` | Warn about a `return` statement that can never be reached — a more targeted subset of `-Wunreachable-code`. |
| `-Wtautological-unsigned-zero-compare` | Warn about a comparison of an unsigned value against `0` that is always true or false (e.g. `unsigned >= 0`). |
| `-Wtautological-type-limit-compare` | Warn about a comparison that is always true/false because the compared type's range can't exceed the given limit. |
| `-Wunused-variable` | Warn about a local or file-scope variable that is declared but never used. |
| `-Wunused-exception-parameter` | Warn about a `catch` parameter that is declared but never used. |
| `-Wunused-lambda-capture` | Warn about a lambda capture that is never used inside the lambda body. |
| `-Wunused-parameter` | Warn about a function parameter that is declared but never used. |
| `-Wunused-function` | Warn about a `static` function that is declared but never defined or used. |
| `-Wunused-member-function` | Warn about a private member function that is declared but never used. |
| `-Wunused-template` | Warn about an internal-linkage function or member template that is never instantiated. |
| `-Wdeprecated` | Warn about uses of constructs or standard-library entities marked `[[deprecated]]` or deprecated by the C++ standard. |
| `-Wsequence-point` | Warn about code whose result depends on an unspecified order of side effects between sequence points. |
| `-Wunsequenced` | Warn about expressions with unsequenced modifications and accesses to the same scalar object. |
| `-Wtrigraphs` | Warn about trigraphs that might change the meaning of the program. |
| `-Wcomment` | Warn about a `/*` nested inside a `/* */` comment, or a `//` comment continued across lines via a trailing backslash. |
| `-Wuser-defined-literals` | Warn about ill-formed use or definition of a user-defined literal suffix. |
| `-Wunknown-escape-sequence` | Warn about an unrecognized character escape sequence in a string or character literal. |
| `-Wredundant-parens` | Warn about parentheses that are redundant and can be removed without changing the expression's meaning. |
| `-Wvexing-parse` | Warn about a declaration that parses as a function declaration where a variable definition was likely intended (C++'s "most vexing parse"). |
| `-Wshadow-all` | Enable Clang's full family of shadowing warnings — locals, fields, `typedef`s, etc. shadowing an outer declaration. |
| `-Wreturn-stack-address` | Warn about returning the address of, or a reference to, a stack variable, parameter, or temporary that is destroyed when the function returns. |
| `-Wswitch-bool` | Warn when a `switch` statement's controlling expression has `bool` type. |
| `-Wconstant-conversion` | Warn when an implicit conversion of a constant expression would change its value, e.g. an out-of-range literal assigned to a smaller type. |
| `-Wimplicit-int-conversion` | Warn about an implicit integer conversion that may change the value, e.g. converting a wider type to a narrower one. |
| `-Wshift-sign-overflow` | Warn when left-shifting a signed value would overflow into, or past, the sign bit. |
| `-Wsign-compare` | Warn about comparisons between signed and unsigned values that could produce an unexpected result. |
| `-Wc++11-narrowing` | Warn about a narrowing conversion inside a brace-enclosed initializer list, which is ill-formed in standard C++11 and later. |
| `-Wsign-conversion` | Warn about implicit conversions between signed and unsigned integers that may change the value's sign or magnitude. |
| `-Wzero-as-null-pointer-constant` | Warn when a literal `0` is used as a null pointer constant instead of `nullptr`. |
| `-Wtautological-pointer-compare` | Warn about a pointer comparison that is always true or false, e.g. comparing the address of a local variable against `nullptr`. |
| `-Wparentheses` | Warn about likely-missing parentheses, e.g. mixing `&&`/`||` without grouping, or using assignment as a truth value. |
| `-Wreinterpret-base-class` | Warn about a `reinterpret_cast` between a pointer to a class and a pointer to its base/derived class, which may not point at the expected sub-object. |
| `-Wold-style-cast` | Warn about the use of a C-style cast (`(T)x`) in C++ code instead of a named cast such as `static_cast`. |
| `-Wcast-qual` | Warn when a cast removes a type qualifier from a pointer, e.g. casting away `const` or `volatile`. |
| `-Wpointer-to-int-cast` | Warn about casting a pointer to an integer type too small to hold it without truncation. |
| `-Winfinite-recursion` | Warn about a function call that can be statically determined to recurse indefinitely. |
| `-Warray-bounds` | Warn about an array subscript or index that is statically known to be out of bounds. |
| `-Warray-bounds-pointer-arithmetic` | Warn about pointer arithmetic that is statically known to go out of an array's bounds. |
| `-Wcomma` | Warn about a comma operator whose left-hand side has no side effects, which usually indicates a typo such as a missing `&&`. |
| `-Wunused-value` | Warn about an expression statement whose computed value is discarded with no side effect. |
| `-Wdangling-else` | Warn about an `else` that indentation suggests belongs to a different `if` than the one it actually binds to. |
| `-Wmisleading-indentation` | Warn about code whose indentation suggests a different block structure than the braces actually produce. |
| `-Wempty-body` | Warn about an empty body (a stray `;`) for an `if`/`else`/`for`/`while` statement, which usually indicates a missing block. |
| `-Wimplicit-fallthrough` | Warn about `switch` cases that fall through to the next case without an explicit `break`, unless annotated with `[[fallthrough]]`. |
| `-Wswitch` | Warn when a `switch` on an `enum` doesn't handle all enumerators and has no `default`. |
| `-Wswitch-default` | Warn when a `switch` statement has no `default` label. |
| `-Wswitch-enum` | Warn when a `switch` on an `enum` doesn't have a case for every enumerator, even if a `default` is present. |
| `-Wdangling-gsl` | Warn about a pointer/reference obtained from a temporary lifetime-annotated (`gsl::`) object that will dangle once the temporary is destroyed. |
| `-Winvalid-noreturn` | Warn about a function declared `[[noreturn]]` that can actually return. |
| `-Wreturn-type` | Warn about a non-`void` function with a code path lacking a `return`, or a `void` function returning a value. |
| `-Wignored-qualifiers` | Warn when a `const`/`volatile` qualifier on a return type has no effect, e.g. on a by-value return. |
| `-Wshadow` | Warn whenever a local variable, parameter, or type shadows another one of the same name from an outer scope. |
| `-Wenum-compare` | Warn about comparisons between values of two different enumerated types. |
| `-Wuninitialized` | Warn about variables used before being initialized on some code path. |
| `-Wduplicate-enum` | Warn about two enumerators in the same enum sharing the same value where it looks unintentional. |
| `-Winconsistent-missing-destructor-override` | Warn when a class overrides a base class's virtual destructor without marking its own `override`. |
| `-Winconsistent-missing-override` | Warn when a virtual function overrides a base-class member but isn't itself marked `override`. |
| `-Wextra-semi-stmt` | Warn about an extraneous, empty statement caused by a stray semicolon. |
| `-Wcall-to-pure-virtual-from-ctor-dtor` | Warn about a constructor or destructor calling a pure virtual function, which cannot resolve to a derived class's override. |
| `-Wexceptions` | Warn about exception-handling constructs that are ill-formed or behave unexpectedly, e.g. throwing out of a `noexcept` function. |
| `-Wexpansion-to-defined` | Warn when the `defined` operator is produced by macro expansion, which has undefined behavior per the C/C++ standard. |
| `-Wundef` | Warn when a non-macro identifier is evaluated inside `#if` (it silently evaluates to `0`). |
| `-Wendif-labels` | Warn about text following `#endif`/`#else` that isn't a comment. |
| `-Wextra-tokens` | Warn about extra tokens after a preprocessor directive, e.g. trailing text after `#endif`. |
| `-Wembedded-directive` | Warn about a preprocessor directive that appears inside the arguments of a macro invocation. |
| `-Wpragma-once-outside-header` | Warn if `#pragma once` appears in a file that isn't being used as a header. |
| `-Wdelete-incomplete` | Warn about `delete`-ing a pointer to an incomplete type, whose destructor (if any) cannot be run. |

### GCC flags

| Flag | What it does |
|---|---|
| `-Wtype-limits` | Warn about comparisons that are always true or false due to the limited range of the operand's type, e.g. an unsigned value compared `< 0`. |
| `-Wunused-variable` | See `minimal_warnings` above. |
| `-Wunused-local-typedefs` | See `all_wall_warnings` above. |
| `-Wunused-function` | See `all_wall_warnings` above. |
| `-Wtrigraphs` | See `all_wall_warnings` above. |
| `-Wcomment` | See `all_wall_warnings` above. |
| `-Wparentheses` | See `all_wall_warnings` above. |
| `-Wshadow` | See `strict_warnings` (QNX) above. |
| `-Wreturn-local-addr` | See `minimal_warnings` above. |
| `-Wswitch-bool` | See `minimal_warnings` above. |
| `-Wsign-compare` | See `all_wall_warnings` above. |
| `-Wconversion` | See `strict_warnings` above. |
| `-Wfloat-conversion` | See `strict_warnings` (QNX) above. |
| `-Waddress` | See `all_wall_warnings` above. |
| `-Wcast-function-type` | Warn about a function pointer cast to a type with an incompatible signature, which is undefined behavior if called through the cast type. |
| `-Wdangling-else` | See `all_wall_warnings` above. |
| `-Wmisleading-indentation` | See `all_wall_warnings` above. |
| `-Wreturn-type` | See `all_wall_warnings` above. |
| `-Wignored-qualifiers` | Warn when a `const`/`volatile` qualifier on a return type has no effect, e.g. on a by-value return. |
| `-Wenum-compare` | See `all_wall_warnings` above. |
| `-Wuninitialized` | See `all_wall_warnings` above. |
| `-Wterminate` | Warn about a `throw` that would exit a `noexcept` function via `std::terminate`, or a destructor that may throw. |
| `-Wexpansion-to-defined` | Warn when the `defined` operator is produced by macro expansion, which has undefined behavior per the C/C++ standard. |
| `-Wdelete-incomplete` | Warn about `delete`-ing a pointer to an incomplete type, whose destructor (if any) cannot be run. |

---

## Testing

The [`tests/`](../tests) module exercises the warnings features on GCC. It
registers a dedicated toolchain (`score_gcc_toolchain_15`, GCC 15.3.0) in
[`tests/MODULE.bazel`](../tests/MODULE.bazel) with `minimal_warnings`,
`strict_warnings`, `all_wall_warnings`, and `warnings_as_errors` added to
`extra_known_features` — this is the toolchain that must be used to test
these features; it is **not** the same toolchain used for the sanitizer
tests (`score_gcc_x86_64_toolchain_fi`).

[`tests/.bazelrc`](../tests/.bazelrc) defines one `--config` per severity
level, each pinning that toolchain and bundling `warnings_as_errors` so a
false positive turns into a build failure instead of a silent warning:

| Config | Feature enabled |
|---|---|
| `feature_only_gcc_minimal_warnings` | `minimal_warnings` + `warnings_as_errors` |
| `feature_only_gcc_strict_warnings` | `strict_warnings` + `warnings_as_errors` |
| `feature_only_gcc_all_wall_warnings` | `all_wall_warnings` + `warnings_as_errors` |

### Positive test — no false positives

[`tests/warnings/positive_test.cpp`](../tests/warnings/positive_test.cpp) is
idiomatic code that must compile clean at every severity level. Run it as a
normal test, e.g.:

```bash
cd tests
bazel test --config=feature_only_gcc_minimal_warnings //:warnings_positive_test
```

### Negative targets — each severity actually catches its violation

`minimal_warnings_violation`, `strict_warnings_violation`, and
`all_wall_warnings_violation` are `cc_library` targets tagged `manual`,
each containing one documented, intentional violation (see the header
comment in the corresponding file:
[`tests/warnings/minimal_violation.cpp`](../tests/warnings/minimal_violation.cpp),
[`tests/warnings/strict_violation.cpp`](../tests/warnings/strict_violation.cpp),
[`tests/warnings/all_wall_violation.cpp`](../tests/warnings/all_wall_violation.cpp)).
They must **fail to build** under their matching config:

```bash
cd tests
bazel build --config=feature_only_gcc_minimal_warnings //:minimal_warnings_violation
```

These are `cc_library` targets, not tests — `bazel test` doesn't apply to
them (there's no runnable action), so CI invokes `bazel build` directly and
inverts the exit code (see `test-warnings` in
[`.github/workflows/tests.yml`](../.github/workflows/tests.yml)):

```bash
if bazel build --config=feature_only_gcc_minimal_warnings //:minimal_warnings_violation; then
  echo "expected this build to fail, but it succeeded" >&2
  exit 1
fi
```

To confirm a violation file builds clean *without* the warnings feature
enabled (i.e. the failure above really comes from the feature, not from
some other compiler default), build it against the plain toolchain:

```bash
cd tests
bazel build --extra_toolchains=@score_gcc_toolchain_15//:x86_64-linux-gcc_15.3.0 //:minimal_warnings_violation
```

---

## Migrating from toolchain-owned warnings

If you previously relied on GCC warning flags baked directly into
`score_bazel_cpp_toolchains`, see
[`migration-warnings.md`](migration-warnings.md) for the old vs. new
model, compatibility expectations, and required changes.
