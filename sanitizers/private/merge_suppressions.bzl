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

"""Rule to merge suppression files with the same basename by concatenation.

When multiple repositories each supply asan.supp, lsan.supp, tsan.supp and
ubsan.supp, pkg_tar would silently overwrite same-named files. Use this rule
to concatenate them first, then pass the merged outputs to pkg_tar.
"""

def _merge_suppressions_impl(ctx):
    """Merges suppression files with the same basename by concatenation."""

    # Group files by basename
    by_name = {}
    for f in ctx.files.srcs:
        name = f.basename
        if name not in by_name:
            by_name[name] = []
        by_name[name].append(f)

    outputs = []
    for name, files in by_name.items():
        out = ctx.actions.declare_file(name)
        if len(files) == 1:
            ctx.actions.symlink(output = out, target_file = files[0])
        else:
            ctx.actions.run_shell(
                outputs = [out],
                inputs = files,
                command = "cat {} > {}".format(
                    " ".join([f.path for f in files]),
                    out.path,
                ),
            )
        outputs.append(out)

    return [DefaultInfo(files = depset(outputs))]

merge_suppressions = rule(
    implementation = _merge_suppressions_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
    },
    doc = "Concatenates suppression files that share the same basename.",
)
