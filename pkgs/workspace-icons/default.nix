# Icon font for waybar workspace labels, built from <iconDir>/*.svg (one path per file).
# Glyphs sit in Plane 16 private use from U+100000, in sorted file-name order:
# agents = U+100000. Add new SVGs so existing code points keep their order.
# iconDir defaults to the free icons in ./icons. parts/_overlays passes the licensed
# set from the private-assets input when it is available.
{
  runCommand,
  python3,
  iconDir ? ./icons,
}:
runCommand "workspace-icons" { nativeBuildInputs = [ (python3.withPackages (p: [ p.fonttools ])) ]; } ''
  mkdir -p $out/share/fonts/truetype
  python ${./build.py} ${iconDir} $out/share/fonts/truetype/workspace-icons.ttf
''
