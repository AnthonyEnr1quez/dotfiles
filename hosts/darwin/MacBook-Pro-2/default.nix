{ config, pkgs, ... }:
let
  projectsPath =
    if pkgs.stdenvNoCC.hostPlatform.isDarwin then
      "${config.user.home}/Projects"
    else
      "/root/projects";
  mfPath = "${projectsPath}/moov/mf";
  libxml2PkgConfigPath = "${pkgs.libxml2_13.dev}/lib/pkgconfig";

  sift = pkgs.buildGoModule rec {
    pname = "sift";
    version = "0.12.0";
    src = builtins.filterSource
      (path: type: (baseNameOf path) != "samples")
      (pkgs.fetchFromGitHub {
        owner = "timtatt";
        repo = "sift";
        rev = "af0a619d0b5469851993dee22446383fe4c8d5c2";
        sha256 = "sha256-4JSnUQ0uQN9Y4x4ZOS2JU2ewVbDZvFDQXdpFl8Sr6fM=";
      });
    vendorHash = "sha256-z/ugDBTKRL7ixkU1d18vtsi6AcNiquDgy2fb/tLQuA0=";
  };

  oq = pkgs.buildGoModule rec {
    pname = "oq";
    version = "0.0.20";
    src = pkgs.fetchFromGitHub {
      owner = "plutov";
      repo = "oq";
      rev = "c3bbc75c79554f4dab1bf2f46480f570468d953e";
      sha256 = "sha256-DVQyiwlUAwdWBBq3Zoto0Mi/vWhC+lMt8KeFBFSVsF8=";
    };
    vendorHash = "sha256-843hhDJXLkqbfuB4CdFl5suLqgsGIAWlk7st46cJp3c=";
  };

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

  scriptPackages = map
    (s: mkScriptPackage s) [
    { name = "flip"; deps = [ pkgs.coreutils pkgs.findutils ]; }
    { name = "green-thumb"; deps = [ pkgs.findutils pkgs.gnused ]; }
    { name = "pdev-test"; deps = [ pkgs.coreutils pkgs.git ]; }
    { name = "pr-comment"; deps = [ pkgs.jq pkgs.gh ]; }
    { name = "prep-deploy"; deps = [ pkgs.jq pkgs.gh ]; }
  ];
in
{
  hm = {
    mcp.enable = true;

    home = {
      sessionVariables = {
        PROJECTS_PATH = projectsPath;
        BUMPER_PD_PATH = "${mfPath}/platform-dev";
        BUMPER_INFRA_PATH = "${mfPath}/infra";
        PKG_CONFIG_PATH = libxml2PkgConfigPath;
      };

      packages = with pkgs; [
        opentofu
        spacectl
        gotools

        (google-cloud-sdk.withExtraComponents
          (with google-cloud-sdk.components; [
            gke-gcloud-auth-plugin
            gcloud-man-pages
          ])
        )

        pkg-config
        libxml2_13
        sift
        oq
      ] ++ scriptPackages;
    };

    programs = {
      zsh = {
        cdpath = [ mfPath ];
      };

      fish = {
        interactiveShellInit = ''
          set -gx CDPATH $CDPATH . ~ ${mfPath}
        '';
      };

      go.env.GOPRIVATE = [ "github.com/moov-io/*" "github.com/moovfinancial/*" ];
    };
  };
}
