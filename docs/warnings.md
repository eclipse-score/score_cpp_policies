# Compiler Warnings

Centralized GCC warning `cc_feature`s for S-CORE C++ modules. Warnings are
grouped into three cumulative severity levels plus a separate opt-in toggle
that turns warnings into build errors.

## Architecture

```
warnings/
└── gcc/
    ├── features/         # Public cc_feature entry points
    │   └── BUILD          #   minimal_warnings, strict_warnings, all_wall_warnings, warnings_as_errors
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
