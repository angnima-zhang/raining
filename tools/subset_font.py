"""Create the game's small, self-contained Chinese UI font. Requires fonttools."""
import argparse
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path, help='Official NotoSansSC[wght].ttf')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
text = ''.join(p.read_text() for p in (root/'godot/scripts').glob('*.gd'))
font = TTFont(args.source)
font = instantiateVariableFont(font, {'wght': 500}, inplace=True)
options = subset.Options()
options.name_IDs = ['*']
options.name_legacy = True
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=set(range(32, 127)) | {ord(ch) for ch in text})
subsetter.subset(font)
for record in font['name'].names:
    names = {1:'Raining Sans', 2:'Medium', 3:'RainingSans-Medium-UI-Subset', 4:'Raining Sans Medium', 6:'RainingSans-Medium'}
    if record.nameID in names:
        record.string = names[record.nameID].encode(record.getEncoding(), errors='replace')
out = root/'godot/fonts/RainingSans.ttf'
font.save(out)
print(out, out.stat().st_size, 'bytes')
