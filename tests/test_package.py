import json, unittest
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT=Path(__file__).resolve().parents[1]

class Links(HTMLParser):
    def __init__(self):
        super().__init__();self.paths=[]
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        for key in ('src','href'):
            if a.get(key):self.paths.append(a[key])

class PackageTests(unittest.TestCase):
    def test_downloads_and_static_assets_exist(self):
        for page in [ROOT/'docs/index.html',ROOT/'web/index.html']:
            parser=Links();parser.feed(page.read_text(encoding='utf-8'))
            for path in parser.paths:
                parts=urlsplit(path)
                if parts.scheme or path.startswith('#') or not parts.path:continue
                self.assertTrue((page.parent/unquote(parts.path)).is_file(),f'{page.name}: {path}')

    def test_config_does_not_invent_lab_addresses(self):
        cfg=json.loads((ROOT/'config/lab.example.json').read_text())
        self.assertEqual(len(cfg['nodes']),6)
        self.assertTrue(all(n['ip'] is None for n in cfg['nodes']))

    def test_evidence_identifies_its_platform(self):
        data=json.loads((ROOT/'docs/downloads/validacion-portable.json').read_text(encoding='utf-8'))
        self.assertIn('Python',data['source'])
        self.assertIn('NO es evidencia de IIS',data['source'])

if __name__=='__main__':unittest.main()
