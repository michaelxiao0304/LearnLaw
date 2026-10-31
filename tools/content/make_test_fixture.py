#!/usr/bin/env python3
"""Export synthetic fixtures ONLY to the Swift package's test resource directory."""
import argparse
from pathlib import Path
from tests.test_release import ReleaseTests
from compile_bundle import compile_release

parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true', help='Reject drift without writing files')
args = parser.parse_args()
fixture = ReleaseTests()
fixture.setUp()
try:
    output = fixture.root / 'compiled'
    compile_release(fixture.package, fixture.registry, fixture.sources, output, fixture.today)
    destination = Path(__file__).resolve().parents[2] / 'ios/CoreTests/Fixtures'
    for name in ['approved-catalog.json', 'search-index.json']:
        data = (output / name).read_bytes()
        if args.check:
            if not (destination / name).is_file() or (destination / name).read_bytes() != data:
                parser.exit(1, 'Synthetic test fixture drift: ' + name + '\n')
        else:
            destination.mkdir(parents=True, exist_ok=True)
            (destination / name).write_bytes(data)
finally:
    fixture.tearDown()
print('Synthetic Swift test fixtures verified' if args.check else 'Synthetic Swift test fixtures generated')
