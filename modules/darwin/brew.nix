{ pkgs, ... }: {
  homebrew = {
    enable = true;

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
      "logi-options+"
      "postman"
    ];
  };
}
