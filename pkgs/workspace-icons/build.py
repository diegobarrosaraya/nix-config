"""Build a TTF from the SVGs in argv[1]; glyphs start at U+100000 in sorted file order."""
import sys, glob, os
import xml.etree.ElementTree as ET
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path

src, out = sys.argv[1], sys.argv[2]
UPM, ASC, DESC = 1000, 800, -200
files = sorted(glob.glob(os.path.join(src, "*.svg")))
names = [os.path.basename(f)[:-4] for f in files]
glyphs, cmap = {".notdef": TTGlyphPen(None).glyph()}, {}

for i, (f, name) in enumerate(zip(files, names)):
    root = ET.parse(f).getroot()
    vb = [float(v) for v in root.get("viewBox").split()]
    s = UPM / max(vb[2], vb[3])
    pen = TTGlyphPen(None)
    # SVG is y-down; the em box spans y = ASC (top) to DESC (bottom).
    tpen = TransformPen(Cu2QuPen(pen, 1.0), (s, 0, 0, -s, -vb[0] * s, ASC + vb[1] * s))
    for p in root.iter("{http://www.w3.org/2000/svg}path"):
        parse_path(p.get("d"), tpen)
    glyphs[name] = pen.glyph()
    cmap[0x100000 + i] = name

order = [".notdef"] + names
fb = FontBuilder(UPM, isTTF=True)
fb.setupGlyphOrder(order)
fb.setupCharacterMap(cmap)
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics({g: (UPM, 0) for g in order})
fb.setupHorizontalHeader(ascent=ASC, descent=DESC)
fb.setupNameTable({"familyName": "Workspace Icons", "styleName": "Regular"})
fb.setupOS2(sTypoAscender=ASC, sTypoDescender=DESC, usWinAscent=ASC, usWinDescent=-DESC)
fb.setupPost()
fb.save(out)
