# Darwin-side wiring for the agent-sandbox micro VM.
#
# Provides:
#   * a `microvm-run` command on PATH that boots the VM via vfkit. Exit the VM
#     with `poweroff` from its shell.
#   * an opt-in NixOS linux-builder (aarch64-linux) needed to *build* the VM
#     closure. It is off by default; flip `microvm.linuxBuilder.enable = true`
#     and rebuild when you need to (re)build the VM, then turn it back off.
#
# The VM is defined in flake.nix as `nixosConfigurations.agent-sandbox`. The
# `microvm-run` wrapper builds the aarch64-linux VM closure LAZILY at runtime
# (via `nix build`) rather than embedding it as a build-time dependency of the
# darwin system. Embedding it would force every `darwin-rebuild` to build the
# VM, which requires the Linux builder and creates a chicken-and-egg problem.
{ config, lib, pkgs, self, ... }:
let
  cfg = config.microvm.linuxBuilder;

  flakeRef = self.outPath;
  runnerAttr = "nixosConfigurations.agent-sandbox.config.microvm.declaredRunner";

  microvm-run = pkgs.writeShellScriptBin "microvm-run" ''
    set -euo pipefail

    echo "Building agent-sandbox micro VM (this needs the Linux builder)..." >&2
    runner=$(${lib.getExe pkgs.nix} build --no-link --print-out-paths \
      "${flakeRef}#${runnerAttr}")

    # vfkit creates the VM's disk image(s) in the current directory (the image
    # paths in vm.nix are relative). Pin them to a stable per-user location so
    # `microvm-run` works from anywhere and reuses the same persistent store
    # overlay instead of littering images wherever it's launched.
    statedir="$HOME/.local/share/microvm"
    mkdir -p "$statedir"
    cd "$statedir"

    # virtiofsd requires the shared host dirs to exist before launch. The
    # projects share (~/projects) is assumed to exist; ensure the writable
    # worktrees area does. See extraArgsScript in vm.nix.
    mkdir -p "$statedir/worktrees"

    # Restore terminal settings on exit (vfkit puts the tty in raw mode).
    cleanup() { stty "$(stty -g)"; }
    trap cleanup EXIT
    exec "$runner/bin/microvm-run"
  '';

  worktreesRoot = "$HOME/.local/share/microvm/worktrees";

  # microvm-fetch <repo>
  #   Pull every agent session's branches for <repo> from the shared worktrees
  #   area into the real host repo (~/projects/<repo>) under a namespaced ref
  #   `refs/agent/<session>/*`, so nothing collides with your own branches.
  microvm-fetch = pkgs.writeShellApplication {
    name = "microvm-fetch";
    runtimeInputs = [ pkgs.git pkgs.coreutils ];
    text = ''
      repo="''${1:-}"
      if [ -z "$repo" ]; then
        echo "usage: microvm-fetch <repo>   (path under ~/projects, e.g. nix/dotfiles)" >&2
        exit 2
      fi

      target="$HOME/projects/$repo"
      sessroot="${worktreesRoot}/$repo"

      if [ ! -e "$target/.git" ]; then
        echo "error: '$target' is not a git repo" >&2
        exit 1
      fi
      if [ ! -d "$sessroot" ]; then
        echo "no agent sessions found for '$repo' at $sessroot" >&2
        exit 0
      fi

      cd "$target"
      found=0
      for sess in "$sessroot"/*/; do
        [ -e "$sess/.git" ] || continue
        found=1
        name="$(basename "$sess")"
        echo "fetching session '$name' -> refs/agent/$name/*" >&2
        git fetch --no-tags "$sess" "refs/heads/*:refs/agent/$name/*"
      done

      if [ "$found" -eq 0 ]; then
        echo "no git clones under $sessroot" >&2
        exit 0
      fi

      echo "done. review with: git for-each-ref refs/agent" >&2
    '';
  };

  # microvm-open <repo> [session]
  #   Open an agent session's live directory in Zed on the host. With no
  #   session, lists the available sessions for <repo>.
  microvm-open = pkgs.writeShellApplication {
    name = "microvm-open";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      repo="''${1:-}"
      session="''${2:-}"
      if [ -z "$repo" ]; then
        echo "usage: microvm-open <repo> [session]" >&2
        exit 2
      fi

      sessroot="${worktreesRoot}/$repo"
      if [ ! -d "$sessroot" ]; then
        echo "no agent sessions for '$repo' at $sessroot" >&2
        exit 1
      fi

      if [ -z "$session" ]; then
        echo "sessions for '$repo':" >&2
        ls -1 "$sessroot" >&2
        echo "run: microvm-open $repo <session>" >&2
        exit 0
      fi

      dir="$sessroot/$session"
      if [ ! -d "$dir" ]; then
        echo "error: no such session: $dir" >&2
        exit 1
      fi

      exec zeditor "$dir"
    '';
  };

  # microvm-review <repo> <session> [branch]
  #   Check out an agent session's fetched work in a host git worktree so you
  #   can review/merge it natively. Run `microvm-fetch <repo>` first.
  #   With no <branch>, uses the session's default `agent/<session>` branch.
  #   The review worktree is created at ~/projects/<repo>-review/<session>.
  microvm-review = pkgs.writeShellApplication {
    name = "microvm-review";
    runtimeInputs = [ pkgs.git pkgs.coreutils ];
    text = ''
      repo="''${1:-}"
      session="''${2:-}"
      branch="''${3:-agent/$session}"
      if [ -z "$repo" ] || [ -z "$session" ]; then
        echo "usage: microvm-review <repo> <session> [branch]" >&2
        exit 2
      fi

      target="$HOME/projects/$repo"
      if [ ! -e "$target/.git" ]; then
        echo "error: '$target' is not a git repo" >&2
        exit 1
      fi

      ref="refs/agent/$session/$branch"
      cd "$target"
      if ! git rev-parse --verify --quiet "$ref" >/dev/null; then
        echo "error: ref not found: $ref" >&2
        echo "have you run 'microvm-fetch $repo'? available agent refs:" >&2
        git for-each-ref --format='  %(refname)' refs/agent >&2 || true
        exit 1
      fi

      # Sibling review worktree, e.g. ~/projects/nix/dotfiles-review/<session>
      dest="$target-review/$session"
      if [ -e "$dest" ]; then
        echo "review worktree already exists: $dest" >&2
      else
        mkdir -p "$(dirname "$dest")"
        git worktree add "$dest" "$ref"
        echo "review worktree ready: $dest" >&2
      fi
      echo "$dest"
    '';
  };
in
{
  options.microvm.linuxBuilder.enable = lib.mkEnableOption ''
    the aarch64-linux NixOS linux-builder used to build the agent-sandbox
    micro VM. Enable temporarily while iterating on the VM config, then
    disable to free the builder VM's resources (see the sizing below)
  '';

  config = {
    environment.systemPackages = [ microvm-run microvm-fetch microvm-open microvm-review ];

    nix = lib.mkIf cfg.enable {
      distributedBuilds = true;
      linux-builder = {
        enable = true;
        systems = [ "aarch64-linux" ];

        # Beefed-up builder VM for faster aarch64-linux builds while iterating.
        # Defaults are ~1 vCPU / 3 GiB. Sized to leave headroom on a 16 GiB
        # M3 MacBook Air (8 cores): give the builder 6 cores / 6 GiB so macOS
        # keeps ~10 GiB and avoids heavy swapping.
        # (Only matters while linuxBuilder.enable = true.)
        maxJobs = 4;
        config = {
          virtualisation = {
            cores = 6;
            darwin-builder = {
              memorySize = 6144; # 6 GiB
              diskSize = 61440; # 60 GiB
            };
          };
        };
      };
    };
  };
}
