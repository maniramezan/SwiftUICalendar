import copy
import importlib.util
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest


sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[1] / "configure-ui-test-products.py"
SPEC = importlib.util.spec_from_file_location("configure_ui_test_products", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ConfigureUITestProductsTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.products = Path(self.directory.name)

    def export(self, index, configurations, format=plistlib.FMT_XML):
        path = self.products / "Tests" / str(index) / "Tests.xctestrun"
        path.parent.mkdir(parents=True)
        data = {"TestConfigurations": [
            {"Name": name, "TestTargets": [{
                "IsUITestBundle": True,
                "ParallelizationEnabled": True,
                "TestLanguage": name,
                "SkipTestIdentifiers": ["UnselectedSuite"],
                "PreferredScreenCaptureFormat": "screenRecording",
                "UITargetAppPerformanceAntipatternCheckerEnabled": True,
                "EnvironmentVariables": {
                    "DYLD_INSERT_LIBRARIES": "/usr/lib/libRPAC.dylib:/sdk/libXCTestBootstrapInject.dylib:/sdk/libMainThreadChecker.dylib",
                    "PERFC_ENABLE_PROFILE_MODE": "1",
                    "PERFC_RESET_INSERT_LIBRARIES": "1",
                    "KEEP_ME": "yes",
                },
                "UITargetAppEnvironmentVariables": {"DYLD_INSERT_LIBRARIES": "/usr/lib/libRPAC.dylib"},
            }, {
                "IsUITestBundle": False,
                "EnvironmentVariables": {"PERFC_KEEP_FOR_UNIT_TESTS": "yes"},
            }]} for name in configurations
        ]}
        path.write_bytes(plistlib.dumps(data, fmt=format))
        return path, data

    def test_all_configurations_keep_coverage_parallelization_other_injections_and_binaries(self):
        first, original = self.export(0, ["Default"])
        second, locales = self.export(1, ["English", "German", "Persian", "Arabic", "Hebrew"], plistlib.FMT_BINARY)
        binary = self.products / "Binaries" / "app"
        binary.parent.mkdir()
        binary.write_bytes(b"unchanged executable")
        self.assertEqual(6, MODULE.configure(self.products))
        for path, before in [(first, original), (second, locales)]:
            after = plistlib.loads(path.read_bytes())
            expected = copy.deepcopy(before)
            for configuration in expected["TestConfigurations"]:
                target = configuration["TestTargets"][0]
                target["PreferredScreenCaptureFormat"] = "screenshots"
                target["UITargetAppPerformanceAntipatternCheckerEnabled"] = False
                target["EnvironmentVariables"] = {
                    "DYLD_INSERT_LIBRARIES": "/sdk/libXCTestBootstrapInject.dylib:/sdk/libMainThreadChecker.dylib",
                    "KEEP_ME": "yes",
                }
                target["UITargetAppEnvironmentVariables"] = {}
            self.assertEqual(expected, after)
        self.assertEqual(b"unchanged executable", binary.read_bytes())
        self.assertTrue(first.read_bytes().startswith(b"<?xml"))
        self.assertTrue(second.read_bytes().startswith(b"bplist00"))

    def test_unsupported_export_fails_before_any_file_is_modified(self):
        first, _ = self.export(0, ["Default"])
        before = first.read_bytes()
        second, invalid = self.export(1, ["English"])
        del invalid["TestConfigurations"][0]["TestTargets"][0]["UITargetAppPerformanceAntipatternCheckerEnabled"]
        second.write_bytes(plistlib.dumps(invalid))
        with self.assertRaisesRegex(ValueError, "Missing UITargetAppPerformanceAntipatternCheckerEnabled"):
            MODULE.configure(self.products)
        self.assertEqual(before, first.read_bytes())

    def test_missing_export_fails_instead_of_silently_running_with_defaults(self):
        with self.assertRaisesRegex(ValueError, "No exported test plans"):
            MODULE.configure(self.products)


if __name__ == "__main__":
    unittest.main()
