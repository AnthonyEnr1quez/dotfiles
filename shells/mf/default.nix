{ pkgs }:
let
  bumper = pkgs.buildGoModule rec {
    pname = "bumper";
    version = "0.7.0";
    src = builtins.fetchGit {
      url = "git@github.com:moovfinancial/bumper.git";
      ref = "refs/tags/v${version}";
      rev = "5ba9910ffe583dcaccace03ba8130f96b7243aca";
    };
    doCheck = false;
    # vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    vendorHash = "sha256-yjHEIJ7MWg7JUUDl/3zvGG+Mumnk2CV6enYL+xMNsNY=";
  };

  librdkafka = pkgs.rdkafka.overrideAttrs (_: rec {
    version = "unstable-2025-05-29";
    src = pkgs.fetchFromGitHub {
      owner = "confluentinc";
      repo = "librdkafka";
      rev = "3f52de491f8aae1d71a9a0b3f1c07bfd6df4aec3"; # tags/v*
      sha256 = "0gbsv5qfbyik7rym39y4lkn3r5wljgnhgsxn6ya9gnzyqx5avya7";
    };
  });

  # Function to create a basic shell script package
  # https://www.ertt.ca/nix/shell-scripts/#org6f67de6
  # https://github.com/ponkila/HomestakerOS/blob/56523feb33a4e797a1a12e9e11321b6d4b6ce635/flake.nix#L39
  mkScriptPackage = { name, deps }:
    let
      scriptPath = ./scripts + "/${name}.sh";
      script = (pkgs.writeScriptBin name (builtins.readFile scriptPath)).overrideAttrs (old: {
        buildCommand = "${old.buildCommand}\n patchShebangs $out";
      });
    in
    pkgs.symlinkJoin {
      inherit name;
      paths = [ script ] ++ deps;
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
    };

  scriptDefs = {
    flip = mkScriptPackage {
      name = "flip";
      deps = [
        pkgs.coreutils
        pkgs.findutils
      ];
    };
    green-thumb = mkScriptPackage {
      name = "green-thumb";
      deps = [
        pkgs.findutils
        pkgs.gnused
      ];
    };
    pdev-test = mkScriptPackage {
      name = "pdev-test";
      deps = [
        bumper
        pkgs.coreutils
        pkgs.git
      ];
    };
    pr-comment = mkScriptPackage {
      name = "pr-comment";
      deps = [
        pkgs.jq
        pkgs.gh
      ];
    };
    prep-deploy = mkScriptPackage {
      name = "prep-deploy";
      deps = [
        pkgs.jq
        pkgs.gh
      ];
    };
  };
  scripts = with builtins; (map (key: getAttr key scriptDefs) (attrNames scriptDefs));

in
pkgs.mkShell {
  packages = with pkgs; [
    librdkafka
    pkg-config
    libxml2
    libxml2.dev
    libxslt # TODO unneeded?

    openssl
    openssl.dev

    cyrus_sasl
    zstd

    bumper
  ] ++ scripts;

  # env vars
  BUMPER_PD_PATH = "/Users/anthony.enriquez/Projects/moov/mf/platform-dev";
  BUMPER_INFRA_PATH = "/Users/anthony.enriquez/Projects/moov/mf/infra";
}
