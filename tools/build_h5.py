"""Export Godot Web and create a TapTap H5 ZIP with index.html at its root."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--godot', default=shutil.which('godot'), help='Godot 4.7.2 executable')
args = parser.parse_args()
if not args.godot:
    parser.error('Provide --godot /path/to/Godot (matching Web release template required)')
root = Path(__file__).resolve().parents[1]
project = root/'godot'
web = project/'build/web'
web.mkdir(parents=True, exist_ok=True)
# Restrict cleanup and packaging to this preset's known output names.
export_names = {'index.html', 'index.js', 'index.wasm', 'index.pck', 'index.png',
                'index.audio.worklet.js', 'index.audio.position.worklet.js'}
for name in export_names:
    path = web/name
    if path.is_file():
        path.unlink()
subprocess.run([args.godot, '--headless', '--path', str(project), '--editor', '--import', '--quit'], check=True)
subprocess.run([args.godot, '--headless', '--path', str(project), '--export-release', 'Web', str(web/'index.html')], check=True)
required = ['index.html', 'index.js', 'index.wasm', 'index.pck']
missing = [name for name in required if not (web/name).is_file()]
if missing:
    raise SystemExit('Incomplete Web export: '+', '.join(missing))
# Only include the files emitted under the export's index basename.
files = sorted(web/name for name in export_names if (web/name).is_file())
license_file = project/'fonts/OFL.txt'
archive = project/'build/raining-h5.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as output:
    for path in files:
        output.write(path, path.name)
    output.write(license_file, 'OFL.txt')
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    assert set(required).issubset(package.namelist())
    assert not any(name.startswith(('/', '..')) for name in package.namelist())
report = {
    'target':'TapTap H5', 'orientation':'landscape', 'design_size':[1280,720],
    'threads':False, 'package_bytes':archive.stat().st_size,
    'uncompressed_bytes':sum(p.stat().st_size for p in files)+license_file.stat().st_size,
    'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
    'files':{p.name:p.stat().st_size for p in files},
    'status':'built; platform upload, review and device test not performed',
}
(project/'build/h5-build-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps({'package':str(archive), **report}, ensure_ascii=False, indent=2))
