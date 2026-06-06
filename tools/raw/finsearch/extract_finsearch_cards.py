#!/usr/bin/env python3
import codecs, json, re, sys
from pathlib import Path

js_path = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)
text = js_path.read_text(errors='ignore')
match = re.search(r"e\.exports=JSON\.parse\(\'(.+?)\'\)\}", text, re.S)
if not match:
    raise SystemExit('Could not find finsearch card JSON module')
cards = json.loads(codecs.decode(match.group(1), 'unicode_escape'))
media = sorted(set(re.findall(r"static/media/([^\"']+)", text)))
(out_dir / 'finsearch_cards_raw.json').write_text(json.dumps(cards, ensure_ascii=False, indent=2))
(out_dir / 'finsearch_assets_manifest.json').write_text(json.dumps([
    {'filename': fn, 'suggestedUrl': 'https://navarog.github.io/finsearch/static/media/' + fn}
    for fn in media
], ensure_ascii=False, indent=2))
print(f'Extracted {len(cards)} cards and {len(media)} media references')
