{ ... }:
{
  flake.modules.homeManager.desktop-common-font =
{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [

    nerd-fonts.symbols-only
    source-han-mono
    source-han-sans

    noto-fonts
  ];
};
}
