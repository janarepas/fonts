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
            family.mkdir(parents=True)
            (family / 'Regular.ttf').write_text(f'fixture {i}')
            (family / 'Bold.ttf').write_text(f'bold {i}')
        env = dict(os.environ, TERM='xterm', XDG_DATA_HOME=str(root / 'target'))
        self.child = pexpect.spawn('bash', [str(root / SCRIPT.name)],
                                   env=env, dimensions=(24, 80), encoding='utf-8', timeout=8)
        self.child.expect('Page 1/3')

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
        self.move('\x1b[C', 31, 2)
        self.move('j', 33, 2)
        self.move('\x1b[D', 3, 1)
        self.move('\x1b[C', 33, 2)
        self.move('\x1b[C', 63, 3)
        self.move('j', 65, 3)
        # No wrapping at boundaries; next input proves the cursor stayed put.
        self.child.send('\x1b[C')
        self.move('k', 63, 3)
        self.move('\x1b[D', 33, 2)
        self.move('\x1b[D', 3, 1)
        self.child.send('\x1b[D')
        self.move('j', 5, 1)

    def test_search_toggle_variant_and_cancel(self):
        self.child.send(' ')
        self.child.expect('Changes: 2')
        self.child.send('/')
        self.child.expect('Search: ')
        self.child.send('hjkl\n')
        self.child.expect('No matches.')
        self.child.expect('0/0  Page 1/1')
        self.child.send('r')
        self.child.expect('1/65  Page 1/3')
        self.child.send('\r')
        self.child.expect('variants')
        self.child.expect('1/2  Page 1/1')
        self.child.send(' ')
        self.child.expect('Changes: 1')
        self.child.send('b')
        self.child.expect('1/65  Page 1/3')
        self.child.send('s')
        self.child.expect('REVIEW CHANGES')
        self.child.expect('Install: 1')
        self.child.send('n')
        self.child.expect(pexpect.EOF)
        self.assertFalse((Path(self.tmp.name) / 'target').exists())

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
