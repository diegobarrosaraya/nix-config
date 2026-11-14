# Static FILL=1 instance of Material Symbols Outlined. GTK3 CSS (waybar) has no
# font-variation-settings, so the filled style needs its own font family.
{ runCommand, material-symbols, python3Packages }:
runCommand "material-symbols-filled" { nativeBuildInputs = [ python3Packages.fonttools ]; } ''
  mkdir -p $out/share/fonts/truetype
  fonttools varLib.instancer ${material-symbols}/share/fonts/truetype/MaterialSymbolsOutlined*.ttf \
    FILL=1 GRAD=0 opsz=24 wght=400 -o $out/share/fonts/truetype/MaterialSymbolsFilled.ttf
  # Rename, or fontconfig sees a second "Material Symbols Outlined".
  python3 - <<'PY'
  from fontTools.ttLib import TTFont
  import os
  p = os.environ["out"] + "/share/fonts/truetype/MaterialSymbolsFilled.ttf"
  f = TTFont(p)
  for r in f["name"].names:
      if r.nameID in (1, 16): r.string = "Material Symbols Filled"
      elif r.nameID in (2, 17): r.string = "Regular"
      elif r.nameID == 4: r.string = "Material Symbols Filled"
      elif r.nameID == 6: r.string = "MaterialSymbolsFilled-Regular"
  f.save(p)
  PY
''
