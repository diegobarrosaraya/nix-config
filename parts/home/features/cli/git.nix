{ ... }:
{
  flake.modules.homeManager.cli-git =
{ config, lib, pkgs, ... }:
{
  # Signing needs the key in the agent, so only hosts that hold the git key set this.
  options.custom.git.signingKey = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Public key file used to sign commits over ssh. Null leaves signing off.";
  };

  config.programs.git = {
    enable = true;
    package = pkgs.gitFull;
    signing =
      if config.custom.git.signingKey == null then
        { format = null; }
      else
        {
          format = "ssh";
          key = config.custom.git.signingKey;
          signByDefault = true;
        };

    ignores = [
      ".direnv"
      "result"
    ];

    settings = {

      url."https://github.com/" = {
        insteadOf = "git://github.com/";
      };
      alias = {
        pushall = "!git remote | xargs -L1 git push --all";
        graph = "log --decorate --oneline --graph";
      };
      credential = {
        "https://github.com".helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
        "https://gist.github.com".helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
      user = {

        name = "DiegoBarrosA";
        email = "git@diegobarrosaraya.com";
      };
      init = {
        feature.manyFiles = true;
        init.defaultBranch = "main";
      };
      lfs = {
        enable = true;
      };

    };
  };
}
;
}
