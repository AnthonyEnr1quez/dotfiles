{ self, inputs, config, lib, pkgs, ... }: {
  imports = [ ./primary.nix ./secrets ];

  programs = {
    fish.enable = true;
    zsh = {
      enable = true;
      enableCompletion = true;
      enableBashCompletion = true;
    };
  };

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: prev: {
      opencode = inputs.nixpkgs-opencode.legacyPackages.${final.stdenv.hostPlatform.system}.opencode;
    })
  ];

  user = {
    home = "${
        if pkgs.stdenvNoCC.hostPlatform.isDarwin then "/Users" else "/home"
      }/${config.user.name}";
    shell = pkgs.fish;
  };

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
