{ host, lib, pkgs, ... }:
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
}
