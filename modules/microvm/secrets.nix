{ config, host, lib, ... }:
let
  regularSecrets = lib.filterAttrs (_: secret: !secret.neededForUsers) config.sops.secrets;
in
{
  # Shared host modules can declare application secrets without Linux-only
  # options. This OpenCode appliance restarts its consumer by default; an
  # explicit restartUnits list (including []) overrides the default per secret.
  options.sops.secrets = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      config.restartUnits = lib.mkDefault (
        lib.optional (!config.neededForUsers) "opencode.service"
      );
    }));
  };

  config = {
    sops = {
      defaultSopsFile = ../../secrets/microvms + "/agent-sandbox-${host}.yaml";
      age.keyFile = "/var/lib/agent-state/sops/age-key.txt";
      # sops-nix adds RequiresMountsFor for the key path. Decrypt after the
      # persistent volume mounts, rather than during early system activation.
      useSystemdActivation = true;
    };

    hm.home.sessionVariables.SOPS_AGE_KEY_FILE = config.sops.age.keyFile;

    systemd.tmpfiles.rules = [
      "d /var/lib/agent-state/sops 0700 root root -"
    ];

    # Empty configurations can boot for initial key enrollment. Once secrets
    # exist, a decryption failure must prevent OpenCode from starting.
    systemd.services.opencode = lib.mkIf (regularSecrets != { }) {
      requires = [ "sops-install-secrets.service" ];
      after = [ "sops-install-secrets.service" ];
    };

    hm.programs.opencode.settings.permission = {
      read."/var/lib/agent-state/sops/**" = "deny";
      external_directory = {
        "/var/lib/agent-state/sops" = "deny";
        "/var/lib/agent-state/sops/*" = "deny";
      };
    };
  };
}
