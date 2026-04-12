{ lib, config, pkgs, ... }:
let
  name = "vscode";
in
let
  cfg = config.${name};
  
  # https://github.com/nix-community/nix-vscode-extensions/issues/182
  # Fix invalid semver 1.112.01907 -> 1.112.0
  fixedVersion = "1.112.0";

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

    fontFamily = mkOption {
      description = "The font family to use in the editor.";
      type = types.str;
      default = "Hack Nerd Font Mono";
    };
  };

  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      # Override the package to fix the version string
      package = cfg.package.overrideAttrs (old: {
        version = fixedVersion;
        # We're intentionally only changing the version string for forVSCodeVersion compatibility
        __intentionallyOverridingVersion = true;
      });

      profiles.default = {
        enableExtensionUpdateCheck = false;
        enableUpdateCheck = false;

        userSettings = {
          "workbench.colorTheme" = "Owlet (Default)";
          "files.autoSave" = "afterDelay";
          "editor.bracketPairColorization.enabled" = true;
          "editor.fontFamily" = cfg.fontFamily;
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
          ++ (with (pkgs.forVSCodeVersion fixedVersion).open-vsx; [
            alphabotsec.vscode-eclipse-keybindings
            itsjonq.owlet
            opentofu.vscode-opentofu
          ])
          ++ (with (pkgs.forVSCodeVersion fixedVersion).vscode-marketplace; [
            mrmlnc.vscode-json5
          ])
          ++ (with (pkgs.forVSCodeVersion fixedVersion).vscode-marketplace-release; [
          ]);
      };

      mutableExtensionsDir = false;
    };
  };
}
