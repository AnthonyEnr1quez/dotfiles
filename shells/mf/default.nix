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

  sift = pkgs.buildGoModule rec {
    pname = "sift";
    version = "0.12.0";
    src = builtins.filterSource
      (path: type: (baseNameOf path) != "samples")
      (pkgs.fetchFromGitHub {
        owner = "timtatt";
        repo = "sift";
        rev = "af0a619d0b5469851993dee22446383fe4c8d5c2"; # tags/v*
        sha256 = "sha256-4JSnUQ0uQN9Y4x4ZOS2JU2ewVbDZvFDQXdpFl8Sr6fM=";
      });
    vendorHash = "sha256-LoUg18U5wuQuLnlPAq/r4YG4T2bRqJZD/tmKU0QLevI=";
  };

  oq = pkgs.buildGoModule rec {
    pname = "oq";
    version = "0.0.20";
    src = pkgs.fetchFromGitHub {
      owner = "plutov";
      repo = "oq";
      rev = "c3bbc75c79554f4dab1bf2f46480f570468d953e"; # tags/v*
      sha256 = "sha256-DVQyiwlUAwdWBBq3Zoto0Mi/vWhC+lMt8KeFBFSVsF8=";
    };
    vendorHash = "sha256-843hhDJXLkqbfuB4CdFl5suLqgsGIAWlk7st46cJp3c=";
  };

  librdkafka = pkgs.rdkafka.overrideAttrs (_: rec {
    version = "unstable-2025-10-20";
    src = pkgs.fetchFromGitHub {
      owner = "confluentinc";
      repo = "librdkafka";
      rev = "570c785e9e35812db8f50254bd2f7e0cf47def39"; # tags/v*
      sha256 = "0hs0sj5jl95hpwqffx9m87fkdl93ghm23xd2ri1x0qjq41030nhi";
    };
  });

  apple-sdk = pkgs.apple-sdk_15;

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
pkgs.mkShell ({
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

    sift
    oq

    bumper
  ] ++ scripts;

  env = {
    BUMPER_PD_PATH = "/Users/anthony.enriquez/Projects/moov/mf/platform-dev";
    BUMPER_INFRA_PATH = "/Users/anthony.enriquez/Projects/moov/mf/infra";
  };
} // pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
  buildInputs = [
    apple-sdk
  ];

  # fix ld linked errors
  # https://stackoverflow.com/questions/71112682/ld-warning-dylib-was-built-for-newer-macos-version-11-3-than-being-linked-1
  # ld: warning: object file (.../go/pkg/mod/github.com/confluentinc/confluent-kafka-go/v2@v2.2.0/kafka/librdkafka_vendor/librdkafka_darwin_arm64.a(libcommon-lib-der_ec_key.o))
  # was built for newer macOS version (12.0) than being linked (11.0)
  shellHook = ''
    export MACOSX_DEPLOYMENT_TARGET=${apple-sdk.version}
  '';
})
