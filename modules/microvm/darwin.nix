# Darwin-side wiring for a host's agent-sandbox micro VM.
#
# Provides:
#   * a `microvm` command for foreground/background VM lifecycle management.
#   * an opt-in NixOS linux-builder (aarch64-linux) needed to *build* the VM
#     closure. It is off by default; flip `microvm.linuxBuilder.enable = true`
#     and rebuild when you need to (re)build the VM, then turn it back off.
#
# Each enabled Darwin host selects its matching `agent-sandbox-<host>` output.
# The `microvm` wrapper builds the aarch64-linux VM closure LAZILY at runtime
# (via `nix build`) rather than embedding it as a build-time dependency of the
# darwin system. Embedding it would force every `darwin-rebuild` to build the
# VM, which requires the Linux builder and creates a chicken-and-egg problem.
{ config, host, lib, pkgs, self, ... }:
let
  cfg = config.microvm.linuxBuilder;

  flakeRef = self.outPath;
  guestAddress = "192.168.64.2";
  opencodePort = 4096;
  runnerAttr = "nixosConfigurations.agent-sandbox-${host}.config.microvm.declaredRunner";

  microvm-run = pkgs.writeShellScriptBin "microvm-run" ''
    set -euo pipefail

    agent_secrets_dir=""
    saved_tty=""
    cleanup() {
      if [ -n "$agent_secrets_dir" ]; then
        rm -rf -- "$agent_secrets_dir"
      fi
      if [ -n "$saved_tty" ]; then
        stty "$saved_tty"
      fi
    }
    trap cleanup EXIT
    trap 'exit 1' HUP INT TERM

    echo "Building agent-sandbox micro VM for ${host} (this needs the Linux builder)..." >&2
    runner=$(${lib.getExe pkgs.nix} build --no-link --print-out-paths \
      "${flakeRef}#${runnerAttr}")

    # vfkit creates the VM's disk image(s) in the current directory (the image
    # paths in vm.nix are relative). Pin them to a stable per-user location so
    # `microvm-run` works from anywhere and reuses the same persistent store
    # overlay instead of littering images wherever it's launched.
    statedir="$HOME/.local/share/microvm"
    mkdir -p "$statedir"
    cd "$statedir"

    # vfkit's serial console is our stdio, but the host tty still generates
    # signals: Ctrl-C would SIGINT vfkit, whose signal handler gracefully
    # stops the whole VM. Undefine the signal chars so ^C/^\/^Z are sent to
    # the guest console (interrupting the process *inside* the VM) instead.
    # Exit the VM with `poweroff` at its prompt; if the guest ever hangs,
    # kill vfkit from another terminal.
    #
    # No `exec`: the EXIT trap must restore the tty after vfkit returns.
    saved_tty="$(stty -g)"
    stty intr undef quit undef susp undef

    secret_file="${flakeRef}/secrets/personal.sops.yaml"
    if [ -f "$secret_file" ]; then
      agent_secrets_dir="$(mktemp -d "''${TMPDIR:-/tmp}/agent-secrets.XXXXXX")"
      extract_secret() {
        SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}" \
          ${lib.getExe pkgs.sops} decrypt --extract "[\"$1\"]" "$secret_file" > "$2"
        chmod 0400 "$2"
      }
      mkdir "$agent_secrets_dir/gh"
      extract_secret "gh_hosts" "$agent_secrets_dir/gh/hosts.yml"
      extract_secret "anthropic_api_key" "$agent_secrets_dir/anthropic_api_key"
      printf '%s\n' 'version: "1"' > "$agent_secrets_dir/gh/config.yml"
    else
      echo "No agent GitHub credential configured; starting without GitHub authentication." >&2
    fi

    AGENT_SECRETS_DIR="$agent_secrets_dir" "$runner/bin/microvm-run"
  '';

  opencodeAliases = {
    opencode = "opencode-vm";
    opencode-local = lib.getExe pkgs.opencode;
  };

  opencode-vm = pkgs.writeShellScriptBin "opencode-vm" ''
    set -euo pipefail

    case "$PWD" in
      "$HOME/projects"|"$HOME/Projects")
        relative=""
        ;;
      "$HOME/projects/"*)
        relative="''${PWD#"$HOME/projects"}"
        ;;
      "$HOME/Projects/"*)
        relative="''${PWD#"$HOME/Projects"}"
        ;;
      *)
        echo "opencode-vm must be run under ~/projects" >&2
        exit 2
        ;;
    esac

    if ! ${lib.getExe pkgs.curl} --fail --silent \
      http://${guestAddress}:${toString opencodePort}/global/health >/dev/null; then
      ${microvm}/bin/microvm start
    fi

    exec ${lib.getExe pkgs.opencode} attach http://${guestAddress}:${toString opencodePort} \
      --dir "/root/projects$relative" "$@"
  '';

  microvm = pkgs.writeShellScriptBin "microvm" ''
    set -euo pipefail

    statedir="$HOME/.local/share/microvm"
    pidfile="$statedir/vfkit.pid"
    logfile="$statedir/vfkit.log"

    usage() {
      cat <<'EOF'
    Usage: microvm <command>

    Commands:
      start    Start the VM in the background
      run      Run the VM in the foreground
      stop     Stop the background VM
      restart  Stop and start the VM
      status   Show VM and OpenCode status
      logs     Follow the background VM console log
      help     Show this help
    EOF
    }

    running() {
      [ -r "$pidfile" ] || return 1
      IFS= read -r pid < "$pidfile"
      [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 1
      command="$(/bin/ps -p "$pid" -o command= 2>/dev/null)" || return 1
      case "$command" in
        *vfkit*|*microvm-run*|*microvm@agent-sandbox*) return 0 ;;
        *) return 1 ;;
      esac
    }

    healthy() {
      ${lib.getExe pkgs.curl} --fail --silent \
        http://${guestAddress}:${toString opencodePort}/global/health >/dev/null
    }

    prepare() {
      mkdir -p "$statedir"
      if running; then
        echo "agent-sandbox is already running (PID $pid)." >&2
        return 1
      fi
      rm -f "$pidfile"

      echo "Building/substituting agent-sandbox micro VM for ${host}..." >&2
      runner="$statedir/runner"
      ${lib.getExe pkgs.nix} build --out-link "$runner" \
        "${flakeRef}#${runnerAttr}"
      cd "$statedir"
    }

    case "''${1:-help}" in
      start)
        if running; then
          if healthy; then
            echo "agent-sandbox is already running (PID $pid)." >&2
            exit 0
          fi
          echo "agent-sandbox is running, but OpenCode is unavailable." >&2
          exit 1
        fi
        prepare
        # vfkit's stdio console requires a terminal even when detached.
        ${lib.getExe' pkgs.coreutils "nohup"} /usr/bin/script -q "$logfile" \
          "$runner/bin/microvm-run" </dev/null >/dev/null 2>&1 &
        launcher_pid=$!
        for ((attempt = 0; attempt < 120; attempt++)); do
          if running && healthy; then
            echo "Started agent-sandbox (PID $pid)." >&2
            exit 0
          fi
          if ! kill -0 "$launcher_pid" 2>/dev/null; then
            echo "agent-sandbox failed to start; see $logfile" >&2
            exit 1
          fi
          sleep 1
        done
        echo "Timed out starting agent-sandbox; see $logfile" >&2
        exit 1
        ;;
      run)
        prepare
        saved_tty="$(stty -g)"
        trap 'stty "$saved_tty"' EXIT
        stty intr undef quit undef susp undef
        "$runner/bin/microvm-run"
        ;;
      stop)
        if ! running; then
          echo "agent-sandbox is not running." >&2
          rm -f "$pidfile"
          exit 0
        fi
        kill -INT "$pid"
        for ((attempt = 0; attempt < 30; attempt++)); do
          running || break
          sleep 1
        done
        if running; then
          echo "Timed out stopping agent-sandbox (PID $pid)." >&2
          exit 1
        fi
        rm -f "$pidfile"
        echo "Stopped agent-sandbox." >&2
        ;;
      restart)
        "$0" stop
        exec "$0" start
        ;;
      status)
        if ! running; then
          echo "agent-sandbox is stopped"
          exit 1
        fi
        if healthy; then
          echo "agent-sandbox is running (PID $pid, OpenCode healthy)"
        else
          echo "agent-sandbox is running (PID $pid, OpenCode unavailable)"
        fi
        ;;
      logs)
        mkdir -p "$statedir"
        touch "$logfile"
        exec ${lib.getExe' pkgs.coreutils "tail"} -n 200 -F "$logfile"
        ;;
      help|-h|--help)
        usage
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
  '';
in
{
  options.microvm.linuxBuilder.enable = lib.mkEnableOption ''
    the aarch64-linux NixOS linux-builder used to build the agent-sandbox
    micro VM. Enable temporarily while iterating on the VM config, then
    disable to free the builder VM's resources (see the sizing below)
  '';

  config = lib.mkMerge [
    {
      environment.systemPackages = [ microvm opencode-vm ];
      hm.programs = {
        fish.shellAliases = opencodeAliases;
        zsh.shellAliases = opencodeAliases;
      };
    }

    (lib.mkIf cfg.enable {
      nix = {
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
    })
  ];
}
