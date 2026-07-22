{ lib, config, pkgs, ... }:
let
  name = "vscode";
in
let
  cfg = config.${name};

  # Detect which home-manager module to target based on the package.
  # After nix-community/home-manager@80ab64b, VSCode forks have dedicated modules
  # (programs.vscodium, programs.cursor, etc.) instead of overriding programs.vscode.package.
  isVSCodium = (cfg.package.pname or "") == "vscodium";
  programName = if isVSCodium then "vscodium" else "vscode";

  # vscodium exposes the upstream VSCode version as `vscodeVersion`, while
  # vscode uses its `version` directly.
  vscodeVersion = if isVSCodium then cfg.package.vscodeVersion else cfg.package.version;

  sharedProfile = {
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
      ++ (with (pkgs.forVSCodeVersion vscodeVersion).open-vsx; [
        alphabotsec.vscode-eclipse-keybindings
        itsjonq.owlet
        opentofu.vscode-opentofu
      ])
      ++ (with (pkgs.forVSCodeVersion vscodeVersion).vscode-marketplace; [
        mrmlnc.vscode-json5
      ])
      ++ (with (pkgs.forVSCodeVersion vscodeVersion).vscode-marketplace-release; [
      ]);
  };

  inherit (lib) mkIf mkEnableOption mkOption types;
in
{
  options.${name} = {
    enable = mkEnableOption name;

    package = mkOption {
      description = "The vscode package to use. Determines which home-manager module is targeted (programs.vscode vs programs.vscodium).";
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
    programs.${programName} = {
      enable = true;
      package = cfg.package;
      profiles.default = sharedProfile;
      mutableExtensionsDir = false;
    };
  };
}
