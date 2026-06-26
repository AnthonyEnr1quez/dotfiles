{ pkgs, ... }: {
  homebrew = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;

    global = {
      autoUpdate = false;
      brewfile = true;
    };
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    casks = [
      "alt-tab"
      "postman"
    ];
  };
}
