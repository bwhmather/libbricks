"""
Checks that all source and header files directly import the headers that they
need.
"""
import itertools
import pathlib
import sys

from libbricks_lint import (
    INCLUDE_ROOT,
    PROJECT_ROOT,
    SOURCE_ROOT,
    derive_include_from_path,
    enumerate_header_paths,
    enumerate_source_paths,
    header_paths_for_source_path,
    read_ast_from_path,
    read_includes_from_path,
    resolve_clang_path,
    is_source_path,
    resolve_include_path,
    walk_file_preorder,
)

def test():
    passed = True

    source_path = INCLUDE_ROOT / "bricks.h"

    expected_includes = {
        derive_include_from_path(header)
        for header in INCLUDE_ROOT.glob("**/*.h")
        if not header.name.endswith("-private.h")
        and header != source_path
    }
    expected_includes.add("brk-version.h")
    expected_includes.add("brk-enums.h")

    actual_includes = {
        include
        for include in read_includes_from_path(source_path)
        if resolve_include_path(include).is_relative_to(INCLUDE_ROOT)
        or include in expected_includes
    }

    if actual_includes != expected_includes:
        msg = "======================================================================\n"
        msg += f"FAIL: test_entrypoint: {source_path.relative_to(PROJECT_ROOT)}\n"
        msg += "----------------------------------------------------------------------\n"

        if actual_includes - expected_includes:
            mag += f"{source_path.relative_to(PROJECT_ROOT)} is includes the following additional header files`:\n"
            for include in sorted(actual_includes - expected_includes):
                msg += f"  - {include}\n"
            msg += "\n"


        if expected_includes - actual_includes:
            msg += f"{source_path.relative_to(PROJECT_ROOT)} is missing the following public header files`:\n"
            for include in sorted(expected_includes - actual_includes):
                msg += f"  - {include}\n"
            msg += "\n"


        print(msg, file=sys.stderr)
        passed = False

    return passed


if __name__ == "__main__":
    sys.exit(0 if test() else 1)
