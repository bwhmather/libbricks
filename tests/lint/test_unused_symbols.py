import subprocess
import sys
import os

from libbricks_lint import (
    BUILD_ROOT,
    SOURCE_ROOT,
    enumerate_object_paths,
    source_path_for_object_path,
)


def test():
    passed = True

    consumed = set()

    so_exported_result = subprocess.run(
        ["nm", "--dynamic", BUILD_ROOT / "src/libbricks-1.so"],
        stdout=subprocess.PIPE,
        check=True,
    )
    consumed.update(line[19:].decode() for line in so_exported_result.stdout.splitlines())

    for object_path in enumerate_object_paths():
        consumed_result = subprocess.run(
            ["nm", "--undefined-only", object_path],
            stdout=subprocess.PIPE,
            check=True,
        )
        consumed.update(
            line[19:].decode() for line in consumed_result.stdout.splitlines()
        )

    for object_path in enumerate_object_paths():
        source_path = source_path_for_object_path(object_path)
        if source_path is None:
            continue

        exported_result = subprocess.run(
            ["nm", "--defined-only", "--extern-only", object_path],
            stdout=subprocess.PIPE,
            check=True,
        )
        exported = {
            line[19:].decode() for line in exported_result.stdout.splitlines()
        }

        prefix = os.path.splitext(os.path.basename(source_path))[0].replace('-', '_')
        unused = {
            symbol
            for symbol in exported
            if symbol not in consumed
            and symbol != "main"
            and not symbol.startswith(f"{prefix}_get_")
            and not symbol.startswith(f"{prefix}_set_")
            and not symbol == f"{prefix}_new"
        }

        if unused:
            source_path = source_path_for_object_path(object_path)
            msg = "======================================================================\n"
            msg += f"FAIL: test_unused_symbols: {source_path.relative_to(SOURCE_ROOT)}\n"
            msg += "----------------------------------------------------------------------\n"
            msg += "The following symbols were exported but not used:\n"
            for symbol in sorted(unused):
                msg += f"  - {symbol}\n"

            print(msg, file=sys.stderr)
            passed = False

    return passed


if __name__ == "__main__":
    sys.exit(0 if test() else 1)
