{ ... }:
{
  flake.modules.homeManager.cli-git =
{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    signing = {
      format = null;
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
