{ config, pkgs, ... }: {
  # TODO default dummy sha: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
  programs.vscode = {
    enable = true;
    # TODO for wsl
    package = pkgs.vscodium;

    userSettings = {
      "workbench.colorTheme" = "Owlet (Default))";
      "files.autoSave" = "afterDelay";
      "editor.fontSize" = 14;
      "editor.fontFamily" = "Hack Nerd Font Mono";
      "editor.tabSize" = 2;
    };

    mutableExtensionsDir = false;
    extensions = with pkgs.vscode-extensions; [
      bbenoist.nix
      golang.go
     ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "vscode-eclipse-keybindings";
          publisher = "alphabotsec";
          version = "0.16.1";
          sha256 = "VK4OS7fvpJsHracfHdC7blvh6qV0IJse4vdRud/yT/o=";
        }
        {
          name = "owlet";
          publisher = "itsjonq";
          version = "0.1.22";
          sha256 = "LUlMX8HAw/34PGQEAwI0y4K0pJ1nilv2oVycC7+zeR4=";
        }
      ];
  };
}