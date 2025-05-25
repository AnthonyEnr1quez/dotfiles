{ lib, pkgs, config, ... }:
let
  name = "firefox-dev";
  ffPkg = pkgs.firefox-devedition-bin;

  hasher = pkgs.buildGoModule rec {
    pname = "hasher";
    version = "0.0.1";
    src = pkgs.fetchFromGitHub rec {
      owner = "AnthonyEnr1quez";
      repo = "mozillainstallhash";
      rev = "nix";
      sha256 = "sha256-7F1KmCJwq0EHfrbHGVV9JSCfhnqJdEGC2zGEHwdQ5E8=";
    };
    doCheck = false;
    vendorHash = "sha256-t98JO8ahPaZWcHDLBs90Aq6jbxuz7YOcKGq4Me5LSiE=";
  };
in
let
  firefox-csshacks = pkgs.fetchFromGitHub {
    owner = "MrOtherGuy";
    repo = "firefox-csshacks";
    rev = "20830b86775b873d22b48f0f69dde1503641ea5e"; # master
    sha256 = "0rlwlnq7mh9qvq1p1ai7wdk062pcyzlfwjrwnacanbdqn0dl47kh";
  };

  firefoxDir = "Library/Application\ Support/Firefox";

  installDirHash = builtins.readFile (pkgs.runCommand "getFFHash" { buildInputs = [ hasher ]; } ''
    mozillainstallhash "${ffPkg.outPath}/Applications/Firefox Developer Edition.app/Contents/MacOS" > $out
  '');

  cfg = config.${name};

  inherit (lib) mkIf mkEnableOption mkOption types;
in
{
  options.${name} = {
    enable = mkEnableOption "firefox developer edition";

    bookmarksToolbar = mkOption {
      description = "show the bookmarks toolbar";
      type = types.enum [ "always" "never" ];
      default = "always";
    };

    extraExtensions = mkOption {
      type = types.listOf types.package;
      default = [ ];
    };
  };

  config = mkIf cfg.enable {

    # https://support.mozilla.org/en-US/kb/understanding-depth-profile-installation#w_new-behaviour
    # https://github.com/nix-community/home-manager/issues/3323
    # https://github.com/nix-community/home-manager/issues/5717
    home.file = {
      "${firefoxDir}/profiles.ini".text = ''
        [Install${installDirHash}]
        Default=Profiles/default
        Locked=1
      '';

      "${firefoxDir}/installs.ini".text = ''
        [${installDirHash}]
        Default=Profiles/default
        Locked=1
      '';
    };

    programs.firefox = {
      enable = true;
      package = ffPkg.overrideAttrs (_: rec {
        override = _: ffPkg;
      });

      profiles.default = {
        isDefault = true;

        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          bitwarden
          privacy-badger
          refined-github
          sidebery
          ublock-origin
        ] ++ cfg.extraExtensions;

        settings = {
          # disable auto update
          "app.update.auto" = false;
          "app.update.checkInstallTime" = false;
          "app.update.download.promptMaxAttempts" = 0;
          "app.update.elevation.promptMaxAttempts" = 0;
          "app.update.service.enabled" = false;
          "app.update.staging.enabled" = false;
          "app.update.suppressPrompts" = true;

          # always show bookmarks
          "browser.toolbars.bookmarks.showInPrivateBrowsing" = true;
          "browser.toolbars.bookmarks.visibility" = cfg.bookmarksToolbar;

          # i like oreos but
          "cookiebanners.bannerClicking.enabled" = true;
          "cookiebanners.cookieInjector.enabled" = true;
          "cookiebanners.service.enableGlobalRules" = true;
          "cookiebanners.service.mode" = 1; # 1: reject all, 2: reject all, fall back to accept all
          "cookiebanners.service.mode.privateBrowsing" = 1;

          "extensions.autoDisableScopes" = 0; # auto-enable extensions
          "extensions.pocket.enabled" = false;

          # privacy
          "app.normandy.enabled" = false;
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
          "privacy.userContext.enabled" = true;

          # disable password manager
          "signon.rememberSignons" = false;
          "signon.autofillForms" = false;

          # enabled userchrome
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };

        userChrome = ''
          @import "${firefox-csshacks}/chrome/hide_tabs_toolbar_osx.css";
          @import "${firefox-csshacks}/window_control_placeholder_support.css;
        '';
      };
    };
  };
}
