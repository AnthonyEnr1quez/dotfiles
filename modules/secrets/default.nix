{ config, host, lib, pkgs, ... }:
{
  # The encrypted YAML is only required once this machine declares a secret.
  sops = {
    defaultSopsFile = lib.mkDefault (../../secrets/hosts + "/${host}.yaml");
    age = {
      keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
      # Generate once when secrets are first declared, then enroll the public
      # recipient in .sops.yaml and redeploy. Existing identities are reused.
      generateKey = lib.mkDefault true;
      sshKeyPaths = [ ];
    };
    gnupg.sshKeyPaths = [ ];
  };

  environment.systemPackages = with pkgs; [ age sops ];

  # The operator's editing key is separate from the machine's runtime key.
  # This also gives the sops CLI a consistent location on macOS.
  hm.home.sessionVariables.SOPS_AGE_KEY_FILE =
    lib.mkDefault "${config.user.home}/.config/sops/age/keys.txt";
}
