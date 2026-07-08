#!/usr/bin/env python3
# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************
"""Unit tests for the coverage reporter's untested-files augmentation logic.

These tests exercise the helper functions that identify untested source files
and synthesize 0%-coverage LCOV records, without requiring a full
bazel coverage run or llvm-cov toolchain.
"""

import os
import tempfile
import textwrap
import unittest
from pathlib import Path

from coverage.reporter import (
    _append_zero_coverage_lcov,
    _augment_text_summary,
    _count_instrumentable_lines,
    _covered_sources_from_lcov,
    _escape_html,
    _find_untested_sources,
    _is_likely_executable,
    _lcov_totals,
    _make_html_paths_relative,
    _make_lcov_paths_relative,
    _render_untested_rows,
    _resolve_workspace_root,
)


class IsLikelyExecutableTest(unittest.TestCase):
    def test_executable_statements(self):
        for line in [
            "  return 42;",
            "  int x = foo();",
            "  if (x > 0) {",
            "  bar(x);",
            "  x = *ptr;",
            "  *ptr = value;",
            "  **pp = data;",
        ]:
            self.assertTrue(_is_likely_executable(line), f"should be executable: {line!r}")

    def test_non_executable_lines(self):
        for line in [
            "",
            "   ",
            "// comment",
            "/* block open",
            " * continuation",
            " */",
            "#include <foo.h>",
            '#include "bar.h"',
            "#define FOO 42",
            "#ifdef SOMETHING",
            "#endif",
            "#pragma once",
            "{",
            "}",
            "namespace score {",
            "namespace score::detail {",
            "}  // namespace score",
            "public:",
            "  private:",
            "  protected:",
        ]:
            self.assertFalse(_is_likely_executable(line), f"should NOT be executable: {line!r}")


class CountInstrumentableLinesTest(unittest.TestCase):
    def test_mixed_cpp_file(self):
        content = textwrap.dedent("""\
            // Copyright header
            #include "foo.h"

            namespace test {

            int foo(int x) noexcept
            {
                if (x > 0) {
                    return x + 1;
                }
                return -x;
            }

            }  // namespace test
        """)
        with tempfile.NamedTemporaryFile(mode="w", suffix=".cpp", delete=False) as f:
            f.write(content)
            f.flush()
            try:
                line_numbers, count = _count_instrumentable_lines(f.name)
                self.assertEqual(count, 4)
                self.assertIn(6, line_numbers)   # int foo(int x) noexcept
                self.assertIn(8, line_numbers)   # if (x > 0) {
                self.assertIn(9, line_numbers)   # return x + 1;
                self.assertIn(11, line_numbers)  # return -x;
            finally:
                os.unlink(f.name)

    def test_nonexistent_file(self):
        line_numbers, count = _count_instrumentable_lines("/nonexistent/file.cpp")
        self.assertEqual(count, 0)
        self.assertEqual(line_numbers, [])


class CoveredSourcesFromLcovTest(unittest.TestCase):
    def test_extracts_sf_entries(self):
        lcov = textwrap.dedent("""\
            SF:/workspace/src/a.cpp
            DA:1,5
            DA:2,0
            LF:2
            LH:1
            end_of_record
            SF:/workspace/src/b.cpp
            DA:1,3
            LF:1
            LH:1
            end_of_record
        """)
        sources = _covered_sources_from_lcov(lcov)
        self.assertIn(os.path.realpath("/workspace/src/a.cpp"), sources)
        self.assertIn(os.path.realpath("/workspace/src/b.cpp"), sources)
        self.assertEqual(len(sources), 2)

    def test_empty_lcov(self):
        self.assertEqual(_covered_sources_from_lcov(""), set())


class LcovTotalsTest(unittest.TestCase):
    def test_sums_lh_and_lf_across_records(self):
        lcov = textwrap.dedent("""\
            SF:/workspace/src/a.cpp
            DA:1,5
            DA:2,0
            LF:2
            LH:1
            end_of_record
            SF:/workspace/src/b.cpp
            DA:1,3
            LF:1
            LH:1
            end_of_record
        """)
        self.assertEqual(_lcov_totals(lcov), (2, 3))

    def test_empty_lcov(self):
        self.assertEqual(_lcov_totals(""), (0, 0))


class MakeLcovPathsRelativeTest(unittest.TestCase):
    def test_strips_workspace_prefix_from_sf_lines(self):
        lcov = textwrap.dedent("""\
            SF:/workspace/score_inc_lifecycle/src/a.cpp
            DA:1,5
            DA:2,0
            LF:2
            LH:1
            end_of_record
            SF:/workspace/score_inc_lifecycle/src/b.cpp
            DA:1,3
            LF:1
            LH:1
            end_of_record
        """)
        result = _make_lcov_paths_relative(lcov, "/workspace/score_inc_lifecycle")
        self.assertIn("SF:src/a.cpp\n", result)
        self.assertIn("SF:src/b.cpp\n", result)
        self.assertNotIn("/workspace", result)

    def test_leaves_external_paths_unchanged(self):
        # Files outside workspace_root (e.g. system headers, external repos)
        # should not be modified.
        lcov = textwrap.dedent("""\
            SF:/workspace/myproject/src/main.cpp
            DA:1,1
            end_of_record
            SF:/usr/include/c++/v1/iostream
            DA:42,1
            end_of_record
        """)
        result = _make_lcov_paths_relative(lcov, "/workspace/myproject")
        self.assertIn("SF:src/main.cpp\n", result)
        self.assertIn("SF:/usr/include/c++/v1/iostream\n", result)

    def test_preserves_non_sf_lines(self):
        lcov = textwrap.dedent("""\
            SF:/workspace/project/foo.cpp
            FN:10,_Z3foov
            FNDA:5,_Z3foov
            DA:10,5
            LF:1
            LH:1
            end_of_record
        """)
        result = _make_lcov_paths_relative(lcov, "/workspace/project")
        self.assertIn("FN:10,_Z3foov\n", result)
        self.assertIn("FNDA:5,_Z3foov\n", result)
        self.assertIn("DA:10,5\n", result)
        self.assertIn("end_of_record\n", result)


class MakeHtmlPathsRelativeTest(unittest.TestCase):
    def test_rewrites_source_name_title_to_relative_path(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            html_dir = Path(tmpdir) / "html"
            html_dir.mkdir()
            test_html = html_dir / "foo.html"
            test_html.write_text(
                "<div class='source-name-title'><pre>/workspace/project/src/main.cpp</pre></div>"
            )

            _make_html_paths_relative(html_dir, "/workspace/project")

            content = test_html.read_text()
            self.assertIn("<div class='source-name-title'><pre>src/main.cpp</pre></div>", content)
            self.assertNotIn("/workspace/project", content)

    def test_leaves_external_paths_unchanged(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            html_dir = Path(tmpdir) / "html"
            html_dir.mkdir()
            test_html = html_dir / "foo.html"
            test_html.write_text(
                "<div class='source-name-title'><pre>/usr/include/c++/iostream</pre></div>"
            )

            _make_html_paths_relative(html_dir, "/workspace/project")

            content = test_html.read_text()
            self.assertIn("/usr/include/c++/iostream", content)

    def test_handles_nested_directories(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            html_dir = Path(tmpdir) / "html"
            nested = html_dir / "coverage" / "src"
            nested.mkdir(parents=True)
            test_html = nested / "bar.html"
            test_html.write_text(
                "<div class='source-name-title'><pre>/home/user/myproject/src/utils/helper.cpp</pre></div>"
            )

            _make_html_paths_relative(html_dir, "/home/user/myproject")

            content = test_html.read_text()
            self.assertIn("src/utils/helper.cpp", content)


class FindUntestedSourcesTest(unittest.TestCase):
    def test_filters_covered_and_nonexistent(self):
        with tempfile.TemporaryDirectory() as ws:
            src_a = Path(ws) / "src" / "a.cpp"
            src_b = Path(ws) / "src" / "b.cpp"
            src_a.parent.mkdir(parents=True)
            src_a.write_text("int a() { return 1; }\n")
            src_b.write_text("int b() { return 2; }\n")

            manifest = Path(ws) / "manifest.txt"
            manifest.write_text("src/a.cpp\nsrc/b.cpp\nsrc/gone.cpp\n")

            covered = {str(src_a.resolve())}
            result = _find_untested_sources(manifest, ws, covered, [])
            self.assertEqual(len(result), 1)
            self.assertEqual(result[0], (str(src_b.resolve()), "src/b.cpp"))

    def test_respects_filter_regexes(self):
        with tempfile.TemporaryDirectory() as ws:
            src = Path(ws) / "generated" / "foo.cpp"
            src.parent.mkdir()
            src.write_text("int foo() { return 0; }\n")

            manifest = Path(ws) / "manifest.txt"
            manifest.write_text("generated/foo.cpp\n")

            result = _find_untested_sources(manifest, ws, set(), ["generated/"])
            self.assertEqual(result, [])

    def test_rejects_path_traversal(self):
        with tempfile.TemporaryDirectory() as ws:
            outside = Path(ws).parent / "outside.cpp"
            outside.write_text("int secret() { return 42; }\n")

            manifest = Path(ws) / "manifest.txt"
            manifest.write_text(f"../{outside.name}\n")

            try:
                result = _find_untested_sources(manifest, ws, set(), [])
                self.assertEqual(result, [])
            finally:
                outside.unlink(missing_ok=True)

    def test_finds_sources_reached_only_through_symlinks(self):
        """Regression test: manifest entries are often runfiles symlinks that
        resolve outside workspace_root (e.g. to the real on-disk source tree
        when Bazel runs the reporter sandboxed). These must still be found -
        see the docstring on _find_untested_sources for the historical bug
        this guards against.
        """
        with tempfile.TemporaryDirectory() as real_dir:
            real_src = Path(real_dir) / "real.cpp"
            real_src.write_text("int real() { return 1; }\n")

            with tempfile.TemporaryDirectory() as ws:
                linked_src = Path(ws) / "src" / "linked.cpp"
                linked_src.parent.mkdir(parents=True)
                linked_src.symlink_to(real_src)

                manifest = Path(ws) / "manifest.txt"
                manifest.write_text("src/linked.cpp\n")

                result = _find_untested_sources(manifest, ws, set(), [])
                self.assertEqual(result, [(str(real_src.resolve()), "src/linked.cpp")])


class AppendZeroCoverageLcovTest(unittest.TestCase):
    def test_appends_records_with_lh_zero(self):
        with tempfile.TemporaryDirectory() as ws:
            src = Path(ws) / "untested.cpp"
            src.write_text(textwrap.dedent("""\
                #include "untested.h"
                int foo() {
                    return 42;
                }
            """))
            lcov = "SF:/other.cpp\nDA:1,5\nLF:1\nLH:1\nend_of_record\n"
            result = _append_zero_coverage_lcov(lcov, [str(src)], ws)

            self.assertIn(f"SF:{src}", result)
            self.assertIn("LH:0", result)
            self.assertIn("end_of_record", result)
            lines = result.split("\n")
            sf_lines = [l for l in lines if l.startswith("SF:")]
            self.assertEqual(len(sf_lines), 2)

    def test_empty_untested_returns_original(self):
        lcov = "SF:/a.cpp\nend_of_record\n"
        self.assertEqual(_append_zero_coverage_lcov(lcov, [], "/ws"), lcov)


class ResolveWorkspaceRootTest(unittest.TestCase):
    def test_plain_path_returns_parent_with_trailing_slash(self):
        with tempfile.TemporaryDirectory() as ws:
            module_bazel = Path(ws) / "MODULE.bazel"
            module_bazel.write_text("")
            self.assertEqual(_resolve_workspace_root(str(module_bazel)), f"{ws}/")

    def test_resolves_runfiles_symlink_to_real_workspace(self):
        """Regression test: Rlocation() returns a runfiles-tree path, which is
        a symlink into the current action's sandbox under linux-sandbox. The
        parent of that symlink is an ephemeral sandbox path that stops
        existing once the action finishes; SF: entries and HTML links built
        from it point nowhere in the extracted report. This must resolve to
        the real, stable workspace directory instead.
        """
        with tempfile.TemporaryDirectory() as real_ws:
            real_module_bazel = Path(real_ws) / "MODULE.bazel"
            real_module_bazel.write_text("")

            with tempfile.TemporaryDirectory() as sandbox:
                linked_module_bazel = Path(sandbox) / "runfiles" / "_main" / "MODULE.bazel"
                linked_module_bazel.parent.mkdir(parents=True)
                linked_module_bazel.symlink_to(real_module_bazel)

                self.assertEqual(
                    _resolve_workspace_root(str(linked_module_bazel)), f"{real_ws}/"
                )


class EscapeHtmlTest(unittest.TestCase):
    def test_escapes_all_special_chars(self):
        self.assertIn("&amp;", _escape_html("a & b"))
        self.assertIn("&lt;", _escape_html("<tag>"))
        self.assertIn("&gt;", _escape_html("<tag>"))
        self.assertIn("&#39;", _escape_html("it's"))
        self.assertIn("&quot;", _escape_html('"quoted"'))


class RenderUntestedRowsTest(unittest.TestCase):
    """Regression test for synthetic untested-file pages looking unstyled.

    llvm-cov's own per-source pages render one <tr> per line with a
    'line-number' and 'uncovered-line'/'covered-line' cell, which is what
    style.css actually has rules for. The original implementation dumped the
    whole file into one <pre> block, which loaded style.css successfully but
    used none of its classes - so the page looked broken/unstyled next to a
    genuine llvm-cov page. This locks in the line-per-row structure instead.
    """

    def test_one_row_per_line_with_line_number_and_uncovered_class(self):
        rows = _render_untested_rows("int foo() {\n    return 1;\n}\n")
        self.assertEqual(rows.count("<tr>"), 3)
        self.assertIn("class='line-number'", rows)
        self.assertIn("class='uncovered-line'", rows)
        self.assertIn(">1<", rows)
        self.assertIn(">2<", rows)
        self.assertIn(">3<", rows)

    def test_escapes_source_content(self):
        rows = _render_untested_rows("a < b && c > d\n")
        self.assertIn("&lt;", rows)
        self.assertIn("&gt;", rows)
        self.assertIn("&amp;", rows)

    def test_empty_file_renders_placeholder_row(self):
        rows = _render_untested_rows("")
        self.assertIn("(empty file)", rows)
        self.assertEqual(rows.count("<tr>"), 1)


class AugmentTextSummaryTest(unittest.TestCase):
    def test_appends_banner_without_modifying_totals(self):
        with tempfile.TemporaryDirectory() as ws:
            src = Path(ws) / "untested.cpp"
            src.write_text("int foo() {\n    return 42;\n}\n")

            summary = textwrap.dedent("""\
                Filename                      Functions                          Lines                      Branches
                ---                           ---                                ---                        ---
                TOTAL                               2             0       100.00%           10                0       100.00%           4                0       100.00%
            """)
            lcov_text = "SF:/other.cpp\nDA:1,5\nLF:10\nLH:10\nend_of_record\n"
            result = _augment_text_summary(summary, [str(src)], lcov_text)
            self.assertIn("[score-coverage]", result)
            self.assertIn("WARNING", result)
            self.assertIn("estimated via heuristic", result)
            totals_line = [l for l in result.splitlines() if "TOTAL" in l and "score-coverage" not in l][0]
            self.assertIn("100.00%", totals_line)

    def test_banner_contains_file_count_and_line_estimate(self):
        with tempfile.TemporaryDirectory() as ws:
            src = Path(ws) / "untested.cpp"
            src.write_text("int foo() { return 1; }\n")

            summary = "TOTAL  2  0  100.00%  10  0  100.00%\n"
            lcov_text = "SF:/other.cpp\nDA:1,5\nLF:10\nLH:10\nend_of_record\n"
            result = _augment_text_summary(summary, [str(src)], lcov_text)
            self.assertIn("1 source file(s)", result)
            self.assertIn("~1 instrumentable lines", result)

    def test_banner_contains_combined_percentage_from_lcov_totals(self):
        with tempfile.TemporaryDirectory() as ws:
            src = Path(ws) / "untested.cpp"
            src.write_text("int foo() { return 1; }\n")

            summary = "TOTAL  2  0  100.00%  10  0  100.00%\n"
            # Combined: 8 lines hit out of (8 real + 2 synthetic) = 80.00%.
            lcov_text = (
                "SF:/other.cpp\nDA:1,5\nLF:8\nLH:8\nend_of_record\n"
                f"SF:{src}\nDA:1,0\nDA:2,0\nLF:2\nLH:0\nend_of_record\n"
            )
            result = _augment_text_summary(summary, [str(src)], lcov_text)
            self.assertIn("Estimated combined line coverage", result)
            self.assertIn("~80.00%", result)
            self.assertIn("(8/10 lines)", result)


if __name__ == "__main__":
    unittest.main()
