{ ... }:
{
  flake.modules.homeManager.cli-helix =
{
  pkgs,
  lib,
  config,
  ...
}:
let
  nixfmt = pkgs.nixfmt;
  inherit (config.colorscheme) colors;

  bg = "#${colors.base00 or "000000"}";
in
{
  xdg.configFile."moxide/settings.toml".text = ''
    dailynote = "%Y-%m-%d"
    heading_completions = true
    title_headings = true
    unresolved_diagnostics = true
    semantic_tokens = true
    tags_in_codeblocks = false
    references_in_codeblocks = false
    new_file_folder_path = ""
    daily_notes_folder = ""
    include_md_extension_md_link = false
    include_md_extension_wikilink = false
    hover = true
    case_matching = "Smart"
    inlay_hints = true
    block_transclusion = true
    block_transclusion_length = "Full"
    link_filenames_only = false
  '';

  programs.helix = {
    defaultEditor = true;
    enable = true;
    extraPackages = with pkgs; [
      markdown-oxide
      nil
      vscode-langservers-extracted
      rust-analyzer
      ltex-ls-plus
    ];
    themes.stylix-override = pkgs.writeText "stylix-override.toml" ''
      inherits = "stylix"
      "ui.background" = { bg = "${bg}" }
      "ui.window" = { bg = "${bg}" }
      "ui.gutter" = { bg = "${bg}" }
      "ui.gutter.selected" = { bg = "${bg}" }
      "ui.linenr" = { bg = "${bg}" }
      "ui.linenr.selected" = { bg = "${bg}" }
    '';
    settings = {
      theme = lib.mkForce "stylix-override";
      editor = {
        popup-border = "all";
        line-number = "relative";
        lsp.display-messages = true;
        true-color = true;
        file-picker.hidden = false;
        clipboard-provider = "wayland";
      };
      keys.normal = {
        space.space = "file_picker";
        space.w = ":w";
        space.q = ":q";

        space.r = ":reload-all";
      };
    };
    languages = with pkgs; {
      language-server = {
        efm-lsp-prettier = {
          command = "${efm-langserver}/bin/efm-langserver";
          config = {
            documentFormatting = true;
            languages =
              lib.genAttrs
                [
                  "typescript"
                  "javascript"
                  "typescriptreact"
                  "javascriptreact"
                  "vue"
                  "json"
                  "markdown"
                ]
                (_: [
                  {
                    formatCommand = "${pkgs.prettier}/bin/prettier --stdin-filepath \${INPUT}";
                    formatStdin = true;
                  }
                ]);
          };
        };
        eslint = {
          command = "vscode-eslint-language-server";
          args = [ "--stdio" ];
          config = {
            validate = "on";
            packageManager = "yarn";
            useESLintClass = false;
            codeActionOnSave.mode = "all";
            format = true;
            quiet = false;
            onIgnoredFiles = "off";
            rulesCustomizations = [ ];
            run = "onType";
            nodePath = "";
            workingDirectory.mode = "auto";
            experimental = { };
            problems.shortenToSingleLine = false;
            codeAction = {
              disableRuleComment = {
                enable = true;
                location = "separateLine";
              };
              showDocumentation.enable = true;
            };
          };
        };
        typescript-language-server = {
          command = "${pkgs.typescript-language-server}/bin/typescript-language-server";
          args = [
            "--stdio"
            "--tsserver-path=${pkgs.typescript}/lib/node_modules/typescript/lib"
          ];
          config.documentFormatting = false;
        };
        nil = {
          command = "${pkgs.nil}/bin/nil";
          config.nil = {
            formatting.command = [ "${nixfmt}/bin/nixfmt" ];
            nix.flake.autoEvalInputs = true;
          };
        };

        ltex-ls.command = "ltex-ls-plus";
        markdown-oxide = {
          command = "${pkgs.markdown-oxide}/bin/markdown-oxide";
        };
        rust-analyzer = {
          config.rust-analyzer = {
            cargo.loadOutDirsFromCheck = true;
            checkOnSave.command = "clippy";
            procMacro.enable = true;
            lens = {
              references = true;
              methodReferences = true;
            };
            completion.autoimport.enable = true;
            experimental.procAttrMacros = true;
          };
        };
        omnisharp = {
          command = "omnisharp";
          args = [
            "-l"
            "Error"
            "--languageserver"
            "-z"
          ];
        };
      };
      language =
        let
          jsTsWebLanguageServers = [
            {
              name = "typescript-language-server";
              except-features = [ "format" ];
            }
            "eslint"
            {
              name = "efm-lsp-prettier";
              only-features = [ "format" ];
            }
          ];
        in
        [
          {
            name = "bash";
            auto-format = true;
            file-types = [
              "sh"
              "bash"
            ];
            formatter = {
              command = "${pkgs.shfmt}/bin/shfmt";

              args = [
                "-i"
                "4"
                "-s"
                "-ci"
                "-sr"
              ];
            };
          }

          {
            name = "rust";
            auto-format = false;
            file-types = [
              "lalrpop"
              "rs"
            ];
            language-servers = [ "rust-analyzer" ];
          }

          {
            name = "c-sharp";
            language-servers = [ "omnisharp" ];
          }
          {
            name = "typescript";
            language-servers = jsTsWebLanguageServers;
          }
          {
            name = "javascript";
            language-servers = jsTsWebLanguageServers;
          }
          {
            name = "jsx";
            language-servers = jsTsWebLanguageServers;
          }
          {
            name = "tsx";
            language-servers = jsTsWebLanguageServers;
          }
          {
            name = "vue";
            language-servers = [
              {
                name = "vuels";
                except-features = [ "format" ];
              }
              { name = "efm-lsp-prettier"; }
              "eslint"
            ];
          }
          {
            name = "sql";
            formatter.command = "pg_format";
          }
          {
            name = "nix";
            language-servers = [ "nil" ];
            auto-format = true;
          }
          {
            name = "elixir";
            formatter.command = "${pkgs.beamPackages.elixir}/bin/mix format";
          }

          {
            name = "json";
            language-servers = [
              {
                name = "vscode-json-language-server";
                except-features = [ "format" ];
              }
              "efm-lsp-prettier"
            ];
          }
          {
            name = "markdown";
            language-servers = [
              "markdown-oxide"
              "ltex-ls"
              "efm-lsp-prettier"
            ];
            auto-format = true;
          }

          {
            name = "nu";
            language-servers = [
              { name = "nu"; }
              "nu --lsp"
            ];

            auto-format = true;
          }

          {
            name = "xml";

            file-types = [ "xml" ];
            formatter = {
              command = "${pkgs.yq-go}/bin/yq";
              args = [
                "--input-format"
                "xml"
                "--output-format"
                "xml"
                "--indent"
                "2"
              ];
            };
          }

        ];
    };

  };
}
;
}
