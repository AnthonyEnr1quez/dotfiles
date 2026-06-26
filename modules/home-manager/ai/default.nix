{ pkgs, ... }: {
  imports = [
    ./mcp.nix
    ./opencode
  ];

  home.packages = with pkgs; [
    # herdr TODO, currently just on work pc with brew atm
  ];
}
