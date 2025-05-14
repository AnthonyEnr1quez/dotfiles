{ lib, config, pkgs, ... }:
let
  name = "vscode";
in
let
  cfg = config.${name};

  inherit (lib) mkIf mkEnableOption mkOption types;
in
{
  options.${name} = {
    enable = mkEnableOption name;

    package = mkOption {
      description = "The vscode package to use.";
      type = types.package;
      default = pkgs.vscodium;
    };
  };

  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      package = cfg.package;

      profiles.default = {
        enableExtensionUpdateCheck = false;
        enableUpdateCheck = false;

        userSettings = {
          "workbench.colorTheme" = "Owlet (Default)";
          "files.autoSave" = "afterDelay";
          "editor.bracketPairColorization.enabled" = true;
          "editor.fontSize" = 14;
          "editor.tabSize" = 2;
          "diffEditor.ignoreTrimWhitespace" = false;
          "redhat.telemetry.enabled" = false;
        };

      extensions =
        (with pkgs.vscode-extensions; [
          astro-build.astro-vscode
          bbenoist.nix
          golang.go
          mkhl.direnv
          ms-kubernetes-tools.vscode-kubernetes-tools
          redhat.vscode-yaml
        ])
        ++ (with (pkgs.forVSCodeVersion cfg.package.version).open-vsx; [
          alphabotsec.vscode-eclipse-keybindings
          itsjonq.owlet
        ])
        ++ (with (pkgs.forVSCodeVersion cfg.package.version).vscode-marketplace; [
          gamunu.opentofu
          mrmlnc.vscode-json5
        ])
        ++ (with (pkgs.forVSCodeVersion cfg.package.version).vscode-marketplace-release; [
          # github.copilot
          github.copilot-chat
        ]);
    };

      mutableExtensionsDir = false;
    };
  };
}
