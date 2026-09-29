#!/usr/bin/env python3
"""Strict, offline WEBP USFM importer. No runtime downloads or credentials.

Accepts the publisher archives obtained separately. Unknown syntax fails closed.
Word attributes are separated from prose; note/character/paragraph structure is retained.
"""
import argparse
import hashlib
import json
import re
import sqlite3
import stat
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
EDITION = 'web.engwebp'
REFERENCE = 'org.sophia.web.engwebp'
CREDIT = 'World English Bible (WEB), American English, Protestant edition · eBible.org · Public domain.'
APPLICATION_ID = 0x53504841
VERSION = 'sophia-usfm-1'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()


def archive_files(path):
    result = {}
    with zipfile.ZipFile(path) as archive:
        total = 0
        for entry in archive.infolist():
            name = entry.filename
            p = PurePosixPath(name)
            total += entry.file_size
            if (p.is_absolute() or '..' in p.parts or '\\' in name or ':' in name
                    or name in result or stat.S_ISLNK(entry.external_attr >> 16)
                    or total > 100_000_000 or entry.file_size > 30_000_000):
                raise ValueError('Unsafe archive entry: ' + name)
            result[name] = archive.read(entry).decode('utf-8-sig')
    return result


def normalized(text):
    return ' '.join(text.split())


def anchors(label):
    if re.fullmatch(r'[1-9][0-9]*', label):
        return [int(label)]
    if re.fullmatch(r'[1-9][0-9]*-[1-9][0-9]*', label):
        a, b = map(int, label.split('-'))
        if a <= b and b - a < 100:
            return list(range(a, b + 1))
    # Preserve suffix/unknown source labels, without inventing a canonical mapping.
    return []


def parse_book(source):
    tokens = list(re.finditer(r'\\([+A-Za-z0-9]+\*?)', source))
    if not tokens or tokens[0].group(1) != 'id':
        raise ValueError('Missing USFM id')
    code = source[tokens[0].end():tokens[1].start()].split()[0]
    chapters, introduction, blocks = [], [], []
    chapter = 0
    label = ''
    style = 'p'
    stack = []
    note = None
    note_parts = []
    seen_labels = set()
    last_verse = 0
    metadata = {'id','ide','h','toc1','toc2','toc3','mt1','mt2','mt3','cl','ip','is1','ili'}
    paragraphs = {'p','m','q1','q2','b','pi1','li1','mi','nb'}
    characters = {'w','+w','wj','qs','bk','k','+wh'}

    def add(kind, text, marker=None):
        text = re.sub(r'\s+', ' ', text) if kind == 'body' else normalized(text)
        if not text:
            return
        target = blocks if chapter else introduction
        target.append({'id': f'{code}.{chapter}.{len(target)}', 'kind': kind,
                       'text': text, 'label': label, 'verses': anchors(label),
                       'style': marker or style})

    for index, match in enumerate(tokens):
        marker = match.group(1)
        text = source[match.end():tokens[index + 1].start() if index + 1 < len(tokens) else len(source)]
        if not marker.endswith('*') and text.startswith(' '): text = text[1:]
        if marker in {'f', 'x'}:
            if note is not None:
                raise ValueError('Nested note')
            note, note_parts = marker, []
            continue
        if marker in {'f*','x*'}:
            if note != marker[0] or stack:
                raise ValueError('Unbalanced note')
            add('note', ''.join(note_parts), note)
            note = None
            add('body', text)
            continue
        if marker.rstrip('*') in characters:
            base = marker.rstrip('*')
            if marker.endswith('*'):
                if not stack or stack.pop() != base:
                    raise ValueError('Unbalanced character marker: ' + marker)
            else:
                stack.append(base)
                if base in {'w','+w','+wh'}:
                    text = text.split('|', 1)[0]
            if note:
                note_parts.append(text)
            else:
                # Adjacent inline runs must not acquire invented spaces.
                target = blocks if chapter else introduction
                text = re.sub(r'\s+', ' ', text)
                if text:
                    target.append({'id': f'{code}.{chapter}.{len(target)}', 'kind':'body',
                                   'text':text, 'label':label, 'verses':anchors(label), 'style':('qs' if base == 'qs' and not marker.endswith('*') else style)})
            continue
        if note:
            if marker not in {'fr','ft','fq','fqa','xo','xt'}:
                raise ValueError('Unknown note marker: ' + marker)
            note_parts.append(text)
            continue
        if marker == 'c':
            if stack:
                raise ValueError('Open character style at chapter')
            number = int(text.strip())
            if number != chapter + 1:
                raise ValueError('Chapter ordering')
            chapter = number
            blocks = []
            chapters.append({'schemaVersion':1,'editionID':EDITION,'book':code,'chapter':chapter,'blocks':blocks})
            label, style, seen_labels = '', 'p', set()
            last_verse = 0
        elif marker == 'v':
            parts = text.split(maxsplit=1)
            label = parts[0]
            if not chapter or label in seen_labels:
                raise ValueError('Invalid or duplicate verse')
            mapped = anchors(label)
            if mapped and mapped[0] <= last_verse:
                raise ValueError('Verse ordering')
            if mapped: last_verse = mapped[-1]
            seen_labels.add(label)
            add('label', label)
            if len(parts) > 1:
                # Keep inline whitespace at run boundaries, trim only at paragraph boundary.
                blocks.append({'id':f'{code}.{chapter}.{len(blocks)}','kind':'body','text':re.sub(r'\s+',' ',parts[1]),'label':label,'verses':anchors(label),'style':style})
        elif marker in paragraphs:
            style = marker
            add('break', marker, marker)
            if text.strip():
                add('body', text)
        elif marker in {'d','ms1','sp'}:
            add('heading', text, marker)
        elif marker in metadata:
            if chapter:
                raise ValueError('Unexpected metadata within chapter')
            add('heading', text, marker)
        else:
            raise ValueError('Unknown marker: ' + marker)
    if stack or note:
        raise ValueError('Unclosed USFM structure')
    # Coalesce inline body runs without modifying punctuation or word boundaries.
    for document in chapters:
        merged = []
        for block in document['blocks']:
            if merged and block['kind'] == 'body' and merged[-1]['kind'] == 'body' and block['label'] == merged[-1]['label'] and block['style'] == merged[-1]['style']:
                merged[-1]['text'] += block['text']
            else:
                merged.append(block.copy())
        # Preserve spaces around inline notes; the renderer trims paragraph edges.
        document['blocks'] = merged
    return code, chapters, introduction


def build(usfm, vpl, output):
    files = archive_files(usfm)
    comparison_files = archive_files(vpl)
    books = json.loads((ROOT / 'shared/usfm-books.json').read_text())['books']
    expected = {b['usfm'] for b in books}
    parsed, ancillary = {}, {}
    for name, source in files.items():
        if not name.endswith('.usfm'):
            ancillary[name] = source
            continue
        code = re.match(r'\\id\s+(\S+)', source).group(1)
        if code in {'FRT','GLO'}:
            ancillary[name] = source
            continue
        if code not in expected or code in parsed:
            raise ValueError('Unexpected/duplicate book: ' + code)
        parsed[code] = parse_book(source)
    if set(parsed) != expected:
        raise ValueError('Missing books: ' + str(expected - set(parsed)))
    comparison = {}
    for line in comparison_files['engwebp_vpl.txt'].splitlines():
        m = re.match(r'(\w+) (\d+):([^ ]+) (.*)', line)
        if not m: raise ValueError('Invalid VPL line')
        aliases = {'EZE':'EZK','JOE':'JOL','NAH':'NAM','MAR':'MRK','JOH':'JHN','1JO':'1JN','2JO':'2JN','3JO':'3JN','JAM':'JAS','SON':'SNG','SOL':'SNG','PHI':'PHP'}
        key = (aliases.get(m[1],m[1]), int(m[2]), m[3])
        if key in comparison: raise ValueError('Duplicate VPL key')
        comparison[key] = normalized(m[4])
    actual = {}
    for book in books:
        for doc in parsed[book['usfm']][1]:
            for bi, block in enumerate(doc['blocks']):
                if block['kind'] == 'heading' and block['style'] == 'sp' and block['label']:
                    following = doc['blocks'][bi+1:]
                    if next((b['kind'] for b in following if b['kind'] in {'body','label'}), None) == 'body':
                        key = (doc['book'],doc['chapter'],block['label'])
                        actual[key] = actual.get(key, '') + ' ' + block['text'] + ' '
                if block['kind'] == 'heading' and block['style'] == 'd':
                    key = (doc['book'],doc['chapter'],block['label'] or '1')
                    actual[key] = actual.get(key, '') + ' ' + block['text'] + ' '
                if block['kind'] == 'body' and block['label']:
                    key = (doc['book'],doc['chapter'],block['label'])
                    actual[key] = actual.get(key, '') + (' ' if block['style'] == 'qs' else '') + block['text']
                elif block['kind'] == 'break' and block['label']:
                    key = (doc['book'],doc['chapter'],block['label'])
                    actual[key] = actual.get(key, '') + ' '
    actual = {k: normalized(v) for k,v in actual.items()}
    differences = [{'reference':str(k),'usfm':actual.get(k),'vpl':comparison.get(k)} for k in actual.keys() | comparison.keys() if actual.get(k) != comparison.get(k)]
    output.mkdir(parents=True, exist_ok=True)
    (output / 'comparison-report.json').write_bytes(canonical({'differences':differences,'compared':len(actual)}))
    if differences:
        raise ValueError(f'{len(differences)} independent-format differences; review comparison-report.json')
    payload = [(b,parsed[b['usfm']][1]) for b in books]
    revision = digest(canonical(payload))
    path = output / 'web-engwebp.sqlite'
    if path.exists(): path.unlink()  # output artifact only, never a user database
    db = sqlite3.connect(path)
    db.executescript(f'''
    PRAGMA application_id={APPLICATION_ID}; PRAGMA user_version=1;
    CREATE TABLE edition (id TEXT PRIMARY KEY, payload BLOB NOT NULL);
    CREATE TABLE book (code TEXT PRIMARY KEY, ordinal INTEGER UNIQUE, payload BLOB NOT NULL);
    CREATE TABLE chapter (book TEXT, number INTEGER, payload BLOB NOT NULL, digest TEXT NOT NULL, PRIMARY KEY(book,number));
    CREATE TABLE passage_index (book TEXT, chapter INTEGER, label TEXT, verse INTEGER, block_id TEXT, offset INTEGER, length INTEGER);
    CREATE INDEX passage_lookup ON passage_index(book,chapter,verse);
    CREATE TABLE source_supplement (name TEXT PRIMARY KEY, content TEXT NOT NULL);
    ''')
    edition = {'id':EDITION,'referenceSystemID':REFERENCE,'contentRevision':revision,'name':'World English Bible','abbreviation':'WEB','language':'en-US','translationType':'wordForWord','source':'bundled','attribution':CREDIT,'canCopy':True,'canShare':True}
    db.execute('INSERT INTO edition VALUES (?,?)',(EDITION,canonical(edition)))
    for b in books:
        code = b['usfm']
        docs = parsed[code][1]
        model = {'id':code,'title':b['name'],'testament':b['testament'],'order':b['order'],'chapterCount':len(docs)}
        db.execute('INSERT INTO book VALUES (?,?,?)',(code,b['order'],canonical(model)))
        for doc in docs:
            doc['contentRevision'] = revision
            raw = canonical(doc)
            db.execute('INSERT INTO chapter VALUES (?,?,?,?)',(code,doc['chapter'],raw,digest(raw)))
            for block in doc['blocks']:
                if block['kind'] == 'body':
                    for verse in block['verses'] or [None]:
                        db.execute('INSERT INTO passage_index VALUES (?,?,?,?,?,?,?)',(code,doc['chapter'],block['label'],verse,block['id'],0,len(block['text'].encode('utf-16-le'))//2))
        ancillary[code + '.introduction.json'] = canonical(parsed[code][2]).decode()
    db.executemany('INSERT INTO source_supplement VALUES (?,?)',sorted(ancillary.items()))
    db.commit(); db.execute('VACUUM'); db.close()
    now = datetime.now(timezone.utc).isoformat()
    manifest = {'schemaVersion':1,'editionID':EDITION,'referenceSystemID':REFERENCE,'contentRevision':revision,
        'sourceURL':'https://ebible.org/find/details.php?id=engwebp','retrievalURL':'https://ebible.org/Scriptures/engwebp_usfm.zip',
        'retrievalUTC':datetime.fromtimestamp(usfm.stat().st_mtime,timezone.utc).isoformat(),'generationUTC':now,'generatorVersion':VERSION,'sourceSHA256':digest(usfm.read_bytes()),'sourceBytes':usfm.stat().st_size,
        'databaseSHA256':digest(path.read_bytes()),'databaseBytes':path.stat().st_size,'bookSetDigest':digest(canonical(books)),
        'bookCount':len(books),'chapterCount':sum(len(p[1]) for p in parsed.values()),'attribution':CREDIT,'license':'Public domain; preserve unchanged text when using the World English Bible name.',
        'comparisonSHA256':digest(vpl.read_bytes()),'comparedPassages':len(actual)}
    (output / 'web-engwebp.manifest.json').write_bytes(canonical(manifest))
    print(json.dumps({k:manifest[k] for k in ['bookCount','chapterCount','comparedPassages','databaseSHA256']}))
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--usfm', type=Path, required=True)
    parser.add_argument('--vpl', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.usfm, args.vpl, args.output)
