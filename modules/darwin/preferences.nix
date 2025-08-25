{ pkgs, config, ... }: {
  system.activationScripts.postActivation.text = ''
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    defaults write com.apple.finder QLEnableTextSelection -bool true
    defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
    defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool true
  
    # https://georgegarside.com/blog/macos/imac-m1-accent-colours-any-mac/
    # Have to run manually for some reason...
    # defaults write NSGlobalDomain NSColorSimulateHardwareAccent -bool true
    # defaults write NSGlobalDomain NSColorSimulatedHardwareEnclosureNumber -int 7
  '';

  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 1.0;
      mru-spaces = false; # dont rearrage spaces based on most recent use
    };

    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv"; # list view
      _FXShowPosixPathInTitle = true;
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    LaunchServices.LSQuarantine = false;

    # TODO these might not work with latest osx
    # loginwindow = {
    #   autoLoginUser = "${config.user.name}";
    #   GuestEnabled = false;
    #   SHOWFULLNAME = false;
    # };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
    };

    screencapture = {
      disable-shadow = true;
    };
  };
}
