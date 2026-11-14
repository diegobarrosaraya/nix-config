# Ad hoc nix-on-droid bootstrap zip with jade's sshd and authorized keys baked in.
# Build: scripts/build-jade-bootstrap.sh
# Only the ssh part of jade goes in. The full config (llama.cpp, cli modules) uses
# the flake's nixpkgs, while the bootstrap is pinned to nix-on-droid's own nixpkgs,
# so run `nix-on-droid switch --flake .#jade` after first login for the rest.
{ flake }:
let
  nod = flake.inputs.nix-on-droid;
  hmPath = nod.inputs.home-manager.outPath;
  host = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};

  keys = builtins.toJSON (import ../../parts/_ssh-keys.nix).authorized;
  sshModule = builtins.toFile "ssh-inject.nix" "import ${./bootstrap-ssh.nix} { keys = builtins.fromJSON (builtins.readFile ${builtins.toFile "keys.json" keys}); sshdConfig = ${./sshd_config}; }";

  # pkgs/default.nix hardcodes its config and passes no home-manager-path.
  src = host.runCommand "nix-on-droid-patched" { } ''
    cp -r ${nod} $out; chmod -R u+w $out
    substituteInPlace $out/pkgs/default.nix \
      --replace-fail "isFlake = true;" "isFlake = true; home-manager-path = ${hmPath};" \
      --replace-fail "imports = [ ../modules/build/initial-build.nix ];" \
        "imports = [ ../modules/build/initial-build.nix ${sshModule} ];"
  '';
in
(import "${src}/pkgs" {
  nixpkgs = nod.inputs.nixpkgs-for-bootstrap;
  _nativeSystem = builtins.currentSystem;
  system = "aarch64-linux";
}).customPkgs.bootstrapZip
