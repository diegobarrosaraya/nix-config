# The dark/light pair used where one theme carries both modes (ZenNotes,
# Hermes): "colors" from tinted-schemes and the local colors-light. Values are
# hex without "#", like the other schemes here.
{ inputs, lib, pkgs }:
let
  base16 = inputs.stylix.inputs.base16.lib { inherit pkgs lib; };
  only = lib.filterAttrs (k: _: builtins.match "base0[0-9A-F]" k != null);
in
{
  dark = only (base16.mkSchemeAttrs (inputs.stylix.inputs.tinted-schemes + "/base16/colors.yaml"));
  light = import ./colors-light.nix;
}
