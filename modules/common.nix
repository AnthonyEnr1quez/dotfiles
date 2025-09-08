{ self, inputs, config, lib, pkgs, ... }: {
  imports = [ ./primary.nix ];

  programs = {
    fish.enable = true;
    zsh = {
      enable = true;
      enableCompletion = true;
      enableBashCompletion = true;
    };
  };

  nixpkgs.config.allowUnfree = true;

  user = {
    home = "${
        if pkgs.stdenvNoCC.isDarwin then "/Users" else "/home"
      }/${config.user.name}";
    shell = pkgs.fish;
  };
  users.knownUsers = [
    "${config.user.name}"
  ];

  # bootstrap home manager using system config
  hm = import ./home-manager;

  # let nix manage home-manager profiles and use global nixpkgs
  home-manager = {
    extraSpecialArgs = { inherit self inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
    # backupFileExtension = "backup";
  };

  # environment setup
  environment = {
    # list of acceptable shells in /etc/shells
    shells = with pkgs; [ bash fish zsh ];
  };

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
}
