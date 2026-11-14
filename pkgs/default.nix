{ pkgs, lib ? null, colors ? null, privatePackages ? {}, ... }:

{
  lyrics = pkgs.callPackage ./lyrics { };
  thunderbird-mcp = pkgs.callPackage ./thunderbird-mcp { };
  codex-acp = pkgs.callPackage ./codex-acp { };
  claude-desktop = pkgs.callPackage ./claude-desktop { };
  jcode = pkgs.callPackage ./jcode { };
  windows-overview = pkgs.callPackage ./windows-overview { };
  material-symbols-filled = pkgs.callPackage ./material-symbols-filled.nix { };
  spacedrive-v2 = pkgs.callPackage ./spacedrive-v2 { };
  inherit (pkgs.callPackage ./device-mount.nix { }) device-mount device-umount;
} // privatePackages
