# Import only from real-machine constructors. MicroVMs inherit host application
# modules, but their Home Manager configurations must not gain an admin identity.
{ host, inputs, ... }:
{
  home-manager.sharedModules = [
    inputs.sops-nix.homeManagerModules.sops
    ({ config, lib, ... }: {
      sops = {
        # User-level declarations are independent of system-level secrets.
        # This file is only required once this user declares a secret.
        defaultSopsFile = lib.mkDefault (
          ../../secrets/users + "/${host}/${config.home.username}.yaml"
        );
        age = {
          keyFile = lib.mkDefault "${config.xdg.configHome}/sops/age/keys.txt";
          # Reuse an existing admin key; a new identity needs recipient enrollment.
          generateKey = lib.mkDefault true;
        };
      };

      # The sops CLI edits with the user's identity, not the system machine key.
      home.sessionVariables.SOPS_AGE_KEY_FILE = lib.mkDefault config.sops.age.keyFile;
    })
  ];
}
