"""Preservation reports must not infer identity or silently approve missing evidence."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('preservation', Path(__file__).resolve().parents[1] / 'Tools/check-integration-preservation.py')
preservation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preservation)


class PreservationTests(unittest.TestCase):
    def test_legacy_array_cannot_be_mapped_even_if_hashes_match(self):
        original = ['a' * 64, 'b' * 64]
        report = preservation.compare_baseline(original, {'first': original[0], 'second': original[1]})
        self.assertFalse(report['comparable'])
        self.assertEqual(report['unchanged'], {})
        self.assertEqual(original, ['a' * 64, 'b' * 64])

    def test_named_baseline_compares_missing_and_changed_files(self):
        report = preservation.compare_baseline({'digests': {'app': 'a' * 64, 'absent': None}}, {'app': 'b' * 64, 'absent': None})
        self.assertTrue(report['comparable'])
        self.assertEqual(report['unchanged'], {'app': False, 'absent': True})

    def test_scope_changes_and_invalid_hashes_are_not_a_pass(self):
        for baseline in [{'digests': {}}, {'digests': {'app': 'invalid'}}, {'digests': {'app': 'a' * 64, 'extra': None}}]:
            self.assertFalse(preservation.compare_baseline(baseline, {'app': 'a' * 64})['comparable'])


if __name__ == '__main__':
    unittest.main()
