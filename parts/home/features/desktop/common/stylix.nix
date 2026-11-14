{ ... }:
{
  flake.modules.homeManager.desktop-common-stylix =
    {
      config,
      pkgs,
      lib,
      desktop ? null,
      ...
    }:
    let
      inherit (config.colorscheme) colors;
      isGnome = desktop == "gnome";
    in
    {
      home.packages = [ pkgs.material-symbols-filled ];
      stylix = {
        enable = true;

        cursor =
          if isGnome then
            {
              package = pkgs.adwaita-icon-theme;
              name = "Adwaita";
              size = 24;
            }
          else
            {
              package = pkgs.bibata-cursors;
              name = "Bibata-Modern-Classic";
              size = 28;
            };

        base16Scheme = {
          base00 = colors.base00;
          base01 = colors.base01;
          base02 = colors.base02;
          base03 = colors.base03;
          base04 = colors.base04;
          base05 = colors.base05;
          base06 = colors.base06;
          base07 = colors.base07;
          base08 = colors.base08;
          base09 = colors.base09;
          base0A = colors.base0A;
          base0B = colors.base0B;
          base0C = colors.base0C;
          base0D = colors.base0D;
          base0E = colors.base0E;
          base0F = colors.base0F;
        };

        fonts = {
          monospace = {
            package = pkgs.nerd-fonts.fantasque-sans-mono;
            name = "FantasqueSansM Nerd Font";
          };
          sansSerif = {
            package = pkgs.jost;
            name = "Jost*";
          };
          serif = {
            package = pkgs.noto-fonts;
            name = "Noto Serif";
          };
          emoji = {
            package = pkgs.noto-fonts-monochrome-emoji;
            name = "Noto Emoji";
          };
          sizes = {
            applications = 20;
            desktop = 20;
            popups = 20;
            terminal = 20;
          };
        };

        icons =
          if isGnome then
            {
              enable = true;
              package = pkgs.adwaita-icon-theme;
              dark = "Adwaita";
              light = "Adwaita";
            }
          else
            {
              enable = true;
              package = pkgs.papirus-icon-theme;
              dark = "Papirus-Dark";
              light = "Papirus-Light";
            };

        opacity.terminal = 1.0;

        polarity = config.colorscheme.mode;

        # GUI apps stay stock; only fonts and terminal/CLI tools are themed.
        autoEnable = false;
        targets = {
          font-packages.enable = true;
          fontconfig.enable = true;
          alacritty.enable = true;
          fuzzel.enable = true;
          gtk.enable = !isGnome;
          qt.enable = !isGnome;
          helix.enable = true;
          fzf.enable = true;
          btop.enable = true;
          lazygit.enable = true;
          starship.enable = true;
          tmux.enable = true;
          neovim.enable = true;
          nixvim.enable = true;
          nvf.enable = true;
          fish.enable = true;
          nushell.enable = true;
          k9s.enable = true;
          opencode.enable = true;
        };

        overlays.enable = false;
      };
    };
}
