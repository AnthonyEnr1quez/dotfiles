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

        extensions = with pkgs.vscode-extensions; [
          bbenoist.nix
          golang.go
          github.copilot
          github.copilot-chat
          mkhl.direnv
          astro-build.astro-vscode
          ms-kubernetes-tools.vscode-kubernetes-tools
          redhat.vscode-yaml
          hashicorp.terraform
        ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "vscode-eclipse-keybindings";
            publisher = "alphabotsec";
            version = "0.16.1";
            sha256 = "VK4OS7fvpJsHracfHdC7blvh6qV0IJse4vdRud/yT/o=";
          }
          {
            name = "owlet";
            publisher = "itsjonq";
            version = "0.1.22";
            sha256 = "LUlMX8HAw/34PGQEAwI0y4K0pJ1nilv2oVycC7+zeR4=";
          }
          {
            name = "vscode-json5";
            publisher = "mrmlnc";
            version = "1.0.0";
            sha256 = "XJmlUuKiAWqzvT7tawVY5NHsnUL+hsAjJbrcmxDe8C0=";
          }
        ];
      };

      mutableExtensionsDir = false;
    };
  };
}
