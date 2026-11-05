"""PTY regression tests; run with python3 -m unittest discover -s tests (pexpect)."""
import os
from pathlib import Path
import shutil
import tempfile
import unittest
import pexpect

SCRIPT = Path(__file__).resolve().parents[1] / 'install_fonts.sh'


class FontManagerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        shutil.copyfile(SCRIPT, root / SCRIPT.name)
        for i in range(65):
            family = root / 'fonts' / f'Family{i:02d}'
            if i == 0:
                family = family.with_name('Family00 ITC Avant Garde Gothic Pro')
            family.mkdir(parents=True)
            (family / 'Regular.ttf').write_text(f'fixture {i}')
            (family / 'Bold.ttf').write_text(f'bold {i}')
        env = dict(os.environ, TERM='xterm', XDG_DATA_HOME=str(root / 'target'))
        self.child = pexpect.spawn('bash', [str(root / SCRIPT.name)],
                                   env=env, dimensions=(24, 80), encoding='utf-8', timeout=8)
        self.child.expect('Page 1/3')
        self.initial_screen = self.child.before

    def tearDown(self):
        self.child.close(force=True)
        self.tmp.cleanup()

    def move(self, key, position, page):
        self.child.send(key)
        self.child.expect(f'{position}/65  Page {page}/3')

    def test_navigation_and_page_boundaries(self):
        self.move('l', 2, 1)
        self.move('j', 4, 1)
        self.move('k', 2, 1)
        self.move('h', 1, 1)
        self.move('\x1b[6~', 31, 2)
        self.move('j', 33, 2)
        self.move('\x1b[5~', 3, 1)
        self.move('\x1b[6~', 33, 2)
        self.move('\x1b[6~', 63, 3)
        self.move('j', 65, 3)
        # No wrapping at boundaries; next input proves the cursor stayed put.
        self.child.send('\x1b[6~')
        self.move('k', 63, 3)
        self.move('\x1b[5~', 33, 2)
        self.move('\x1b[5~', 3, 1)
        self.child.send('\x1b[5~')
        self.move('j', 5, 1)

    def test_grid_alignment_and_help(self):
        self.assertIn('s Save  b Back  r Reset  q Quit', self.initial_screen)
        row = next(line for line in self.initial_screen.split('\x1b[2K')
                   if '… (0/2)' in line)
        first_cell, second_cell = row.split('\x1b[0m', 1)
        self.assertEqual(len(first_cell.removeprefix('\x1b[1;30;46m')), 38)
        self.assertTrue(second_cell.startswith(' [ ] Family01 (0/2)'))

    def test_search_toggle_variant_and_cancel(self):
        # Enter must leave the family selected; Space toggles both files.
        self.child.send('\r ')
        self.child.expect('Changes: 2')
        self.child.send('/')
        self.child.expect('Search: ')
        self.child.send('hjkl\n')
        self.child.expect('No matches.')
        self.child.expect('0/0  Page 1/1')
        self.child.send('r')
        self.child.expect('1/65  Page 1/3')
        self.child.send('\x1b[C')
        self.child.expect('variants')
        self.child.expect('1/2  Page 1/1')
        self.child.send(' ')
        self.child.expect('Changes: 1')
        self.child.send('\x1b[D')
        self.child.expect('1/65  Page 1/3')
        self.child.send('s')
        self.child.expect('REVIEW CHANGES')
        self.child.expect('Install: 1')
        self.child.send('n')
        self.child.expect('Changes: 0')
        self.child.send('q')
        self.child.expect(pexpect.EOF)
        self.assertFalse((Path(self.tmp.name) / 'target').exists())

    def test_apply_returns_to_refreshed_family_list(self):
        self.child.send('/')
        self.child.expect('Search: ')
        self.child.send('Family00\n')
        self.child.expect('1/1  Page 1/1')
        self.child.send(' s')
        self.child.expect(r'\x1b\[5;9H\+-{62}\+')
        self.assertNotIn('\x1b[2J', self.child.before)
        self.child.expect('y Apply  n Cancel')
        self.child.send('y')
        self.child.expect('Installed: 2    Removed: 0')
        self.child.expect('Any other key: return to font families')
        self.child.send('\r')
        self.child.expect(r'Search: Family00 +Changes: 0')
        self.child.expect(r'\[✓\] Family00.*\(2/2\)')
        self.child.send(' s')
        self.child.expect('y Apply  n Cancel')
        self.child.send('y')
        self.child.expect('Installed: 0    Removed: 2')
        self.child.send('v')
        self.child.expect('DETAILED LOG')
        self.child.send('q')
        self.child.expect(r'Search: Family00 +Changes: 0')
        self.child.expect(r'\[ \] Family00.*\(0/2\)')
        self.child.send('q')
        self.child.expect(pexpect.EOF)

    def test_resize(self):
        self.child.setwinsize(24, 40)
        self.child.expect('1/65  Page 1/5')
        self.child.send('j')
        self.child.expect('2/65  Page 1/5')
        self.child.setwinsize(24, 120)
        self.child.expect('2/65  Page 1/2')
        self.child.send('j')
        self.child.expect('5/65  Page 1/2')


if __name__ == '__main__':
    unittest.main()
