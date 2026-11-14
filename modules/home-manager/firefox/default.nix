{ lib, pkgs, config, ... }:
let
  name = "firefox";
in
let
  firefox-csshacks = pkgs.fetchFromGitHub {
    owner = "MrOtherGuy";
    repo = "firefox-csshacks";
    rev = "0029e334de8e3210564e5a673553a4d2ce04d01e"; # master
    sha256 = "015ysra9qgk641bs5dsf5n40rdjids0cfgfl8lnizmi4vyjgxpdk";
  };

  cfg = config.${name};

  inherit (lib) mkIf mkEnableOption mkOption types;
in
{
  options.${name} = {
    enable = mkEnableOption name;

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
    programs.firefox = {
      enable = true;
      package =
        if pkgs.stdenv.hostPlatform.isDarwin then
          let
            # The wrapper invalidates Mozilla's signature and team-bound entitlements.
            # Work around https://github.com/NixOS/nixpkgs/issues/583738.
            entitlements = pkgs.writeText "firefox-entitlements.plist" ''
              <?xml version="1.0" encoding="UTF-8"?>
              <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
                "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
              <plist version="1.0">
              <dict>
                <key>com.apple.security.cs.allow-jit</key><true/>
                <key>com.apple.security.cs.disable-library-validation</key><true/>
                <key>com.apple.security.device.audio-input</key><true/>
                <key>com.apple.security.device.camera</key><true/>
                <key>com.apple.security.device.usb</key><true/>
                <key>com.apple.security.personal-information.location</key><true/>
                <key>com.apple.security.smartcard</key><true/>
              </dict>
              </plist>
            '';
          in
          pkgs.firefox-bin.overrideAttrs (old: {
            buildCommand = old.buildCommand + ''
              /usr/bin/codesign --force --sign - --options runtime \
                --identifier org.nixos.firefox --entitlements ${entitlements} \
                "$out/Applications/Firefox.app/Contents/MacOS/.firefox-old"
            '';
          })
        else
          pkgs.firefox-bin;

      # macOS 27 blocks Nix-wrapped Firefox from accessing Mozilla's data directory.
      # Migrate existing data before switching: https://github.com/NixOS/nixpkgs/issues/535123
      configPath = mkIf pkgs.stdenv.hostPlatform.isDarwin "Library/Application Support/org.nixos.firefox";

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

          # ai tings
          "browser.ml.chat.enabled" = false;
          "browser.ml.enable" = false;
          "browser.ml.linkPreview.enabled" = false;

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

          # session restore
          "browser.sessionstore.resume_from_crash" = true;
          "browser.startup.page" = 3; # 3 = restore previous session

          # enabled userchrome
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };

        userChrome = ''
          @import "${firefox-csshacks}/chrome/hide_tabs_toolbar_v2.css";
        '';
      };
    };
  };
}
