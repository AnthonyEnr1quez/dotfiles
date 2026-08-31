{ host, config, pkgs, lib, ... }: {
  hm = {
    home = {

      packages = with pkgs; [
        htop
        fastfetch
        cowsay
      ];

      activation.installExtensions = with lib.hm.dag.entryAfter [ "writeBoundary" ]; ''
        if [ -L ${config.user.home}/.vscode-server/extensions ] ; then
            rm -r ${config.user.home}/.vscode-server/extensions
        fi
        ln -s ${config.user.home}/.vscode/extensions ${config.user.home}/.vscode-server

        if [ -L ${config.user.home}/.vscode-server/data/Machine/settings.json ] ; then
            rm -r ${config.user.home}/.vscode-server/data/Machine/settings.json
        fi
        ln -s ${config.user.home}/.config/Code/User/settings.json ${config.user.home}/.vscode-server/data/Machine/settings.json
      '';

    };

    vscode = {
      enable = true;
      package = pkgs.vscode;
      fontFamily = "Hack";
    };

    # wont bind correctly through hm setting
    programs.zsh.initContent = ''
      bindkey "$terminfo[kcuu1]" history-substring-search-up
      bindkey "$terminfo[kcud1]" history-substring-search-down
    '';
  };
}
