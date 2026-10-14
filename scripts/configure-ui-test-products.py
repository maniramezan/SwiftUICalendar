#!/usr/bin/env python3

"""Configure an exported build for functional UI tests without profiling or video capture."""

import argparse
from pathlib import Path
import plistlib


def configure(products: Path) -> int:
    paths = sorted(products.glob("Tests/*/*.xctestrun"))
    if not paths:
        raise ValueError(f"No exported test plans found in {products}")

    exports = []
    targets = []
    for path in paths:
        contents = path.read_bytes()
        export = plistlib.loads(contents)
        format = plistlib.FMT_BINARY if contents.startswith(b"bplist00") else plistlib.FMT_XML
        exports.append((path, export, format))
        for configuration in export["TestConfigurations"]:
            for target in configuration["TestTargets"]:
                if not target.get("IsUITestBundle"):
                    continue
                # Reject unsupported export formats rather than silently keeping diagnostics on.
                for key in ("PreferredScreenCaptureFormat", "UITargetAppPerformanceAntipatternCheckerEnabled"):
                    if key not in target:
                        raise ValueError(f"Missing {key} in {path}")
                targets.append(target)
    if not targets:
        raise ValueError(f"No UI test targets found in {products}")

    for target in targets:
        target["PreferredScreenCaptureFormat"] = "screenshots"
        target["UITargetAppPerformanceAntipatternCheckerEnabled"] = False
        # Xcode resolves runner profiling into launch variables at export time. Remove only the
        # performance-checker injection; preserve XCTest, Main Thread Checker, and other libraries.
        for key in ("EnvironmentVariables", "TestingEnvironmentVariables", "UITargetAppEnvironmentVariables"):
            environment = target.get(key, {})
            for name in list(environment):
                if name.startswith("PERFC_"):
                    del environment[name]
            libraries = environment.get("DYLD_INSERT_LIBRARIES")
            if libraries is not None:
                libraries = ":".join(
                    library for library in libraries.split(":") if Path(library).name != "libRPAC.dylib"
                )
                if libraries:
                    environment["DYLD_INSERT_LIBRARIES"] = libraries
                else:
                    del environment["DYLD_INSERT_LIBRARIES"]

    # Validate every plan before writing any configuration; leave binary products untouched.
    for path, export, format in exports:
        temporary = path.with_suffix(".xctestrun.tmp")
        with temporary.open("wb") as stream:
            plistlib.dump(export, stream, fmt=format, sort_keys=False)
        temporary.replace(path)
    return len(targets)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("products", type=Path)
    arguments = parser.parse_args()
    print(f"Configured {configure(arguments.products)} UI test configurations")
