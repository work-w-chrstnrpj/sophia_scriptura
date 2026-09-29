import json
from pathlib import Path
import tempfile
import unittest
import zipfile
import ingest


class ImporterTests(unittest.TestCase):
    def archive(self, entries):
        root = tempfile.TemporaryDirectory()
        self.addCleanup(root.cleanup)
        path = Path(root.name) / 'source.zip'
        with zipfile.ZipFile(path, 'w') as archive:
            for name, value in entries: archive.writestr(name, value)
        return path

    def test_rejects_traversal_absolute_and_duplicate_entries(self):
        for name in ['../x', '/absolute', 'a\\b', 'C:x']:
            with self.assertRaises(ValueError): ingest.archive_files(self.archive([(name, 'bad')]))
        with self.assertRaises(ValueError):
            ingest.archive_files(self.archive([('a','x'),('a','y')]))

    def test_rejects_unknown_unclosed_and_duplicate_structure(self):
        for content in ['\\id GEN\n\\c 1\n\\bad text',
                        '\\id GEN\n\\c 1\n\\v 1 \\w word',
                        '\\id GEN\n\\c 2\n\\v 1 word',
                        '\\id GEN\n\\c 1\n\\v 3 word\n\\v 1 reversed',
                        '\\id GEN\n\\c 1\n\\v 1 word\n\\v 1 again']:
            with self.assertRaises(ValueError): ingest.parse_book(content)

    def test_notes_unicode_bridges_and_repeated_text_are_structured(self):
        _, docs, _ = ingest.parse_book('\\id GEN\n\\c 1\n\\p\n\\v 1 \\w Same|strong="x"\\w* text.\\f + \\ft note 👋\\f* More.\n\\q1\n\\v 3-4 Same é text.')
        blocks = docs[0]['blocks']
        self.assertEqual([b['text'] for b in blocks if b['kind'] == 'note'], ['note 👋'])
        body = ''.join(b['text'] for b in blocks if b['kind']=='body')
        self.assertIn('Same text.', body)
        self.assertNotIn('strong', body)
        self.assertNotIn('note',body)
        self.assertEqual(blocks[-1]['verses'], [3,4])
        self.assertEqual(ingest.anchors('3a'), [])

    def test_rejects_missing_and_extra_books_before_output(self):
        for source in ['\\id GEN\n\\c 1\n\\v 1 Word.', '\\id TOB\n\\c 1\n\\v 1 Word.']:
            with tempfile.TemporaryDirectory() as root:
                with self.assertRaises(ValueError):
                    ingest.build(self.archive([('book.usfm',source)]),self.archive([('engwebp_vpl.txt','GEN 1:1 Word.')]),Path(root))


if __name__ == '__main__': unittest.main()
