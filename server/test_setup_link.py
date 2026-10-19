"""Installer QR tests: only load functions, never invoke Docker or read .env."""
import pathlib
import subprocess
import unittest

SCRIPT = pathlib.Path(__file__).with_name('wuselwall')


class SetupLinkTest(unittest.TestCase):
    def run_function(self, command):
        source = SCRIPT.read_text().split('case "${1:-}" in')[0]
        return subprocess.run(['bash'], input=source + '\n' + command,
                              text=True, capture_output=True, check=True).stdout.strip()

    def test_fragment_only_and_separate_origins(self):
        self.assertEqual(
            self.run_function('setup_link https://web.example.org/ https://api.example.org/ 0123456789abcdef01234567'),
            'https://web.example.org/#setup=0123456789abcdef01234567&server=https://api.example.org')

    def test_no_capability_falls_back_to_plain_address(self):
        self.assertEqual(self.run_function('setup_link https://web.example.org https://api.example.org ""'),
                         'https://api.example.org')


if __name__ == '__main__':
    unittest.main()
