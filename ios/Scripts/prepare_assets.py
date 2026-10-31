#!/usr/bin/env python3
"""Copy shared logo exports into deterministic iOS asset catalogs."""
from pathlib import Path
import hashlib, json, shutil

IOS = Path(__file__).resolve().parents[1]
SOURCE = IOS.parent / 'resource' / 'logo' / 'png'
ASSETS = IOS / 'LawSense' / 'Assets.xcassets'

def write(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')

write(ASSETS / 'Contents.json', {'info': {'author': 'xcode', 'version': 1}})
icons = []
for source, appearance in [('icon-1024.png', None), ('icon-dark-1024.png', 'dark')]:
    target = ASSETS / 'AppIcon.appiconset' / source
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SOURCE / source, target)
    item = {'filename': source, 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}
    if appearance: item['appearances'] = [{'appearance': 'luminosity', 'value': appearance}]
    icons.append(item)
write(ASSETS / 'AppIcon.appiconset' / 'Contents.json', {'images': icons, 'info': {'author': 'xcode', 'version': 1}})
for name, source in [('BrandIcon', 'icon-1024.png'), ('BrandMark', 'mark-512.png')]:
    folder = ASSETS / (name + '.imageset')
    folder.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SOURCE / source, folder / source)
    write(folder / 'Contents.json', {'images': [{'filename': source, 'idiom': 'universal'}], 'info': {'author': 'xcode', 'version': 1}})
write(IOS / 'asset-provenance.json', {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(SOURCE.glob('*.png')) if p.name in ['icon-1024.png', 'icon-dark-1024.png', 'mark-512.png']})
print('Prepared AppIcon, BrandIcon and BrandMark from resource/logo/png')
