{ ... }: {
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = false;
    settings.telemetry = "disabled";
  };
}
