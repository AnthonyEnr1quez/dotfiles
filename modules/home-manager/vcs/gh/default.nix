{ config, lib, osConfig, ... }: {
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = lib.mkDefault false;
    settings = {
      git_protocol = lib.mkIf (osConfig.sops.templates ? "gh-hosts.yml") (lib.mkDefault "ssh");
      telemetry = "disabled";
    };
  };

  xdg.configFile."gh/hosts.yml" = lib.mkIf (osConfig.sops.templates ? "gh-hosts.yml") {
    source = config.lib.file.mkOutOfStoreSymlink osConfig.sops.templates."gh-hosts.yml".path;
    force = true;
  };

  # SOPS replaces the account file, so there is no legacy account state to migrate.
  home.activation.migrateGhAccounts = lib.mkIf (osConfig.sops.templates ? "gh-hosts.yml") (
    lib.mkForce (lib.hm.dag.entryBefore [ "linkGeneration" ] "")
  );
}
