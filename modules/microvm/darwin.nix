# Host launcher and optional Linux builder for agent-sandbox-<host>.
# Build the guest at launch so Darwin rebuilds don't require a Linux builder.
{ config, host, lib, pkgs, self, ... }:
let
  cfg = config.microvm.linuxBuilder;

  flakeRef = self.outPath;
  guestMac = (builtins.head self.nixosConfigurations."agent-sandbox-${host}".config.microvm.interfaces).mac;
  opencodePort = 4096;
  runnerAttr = "nixosConfigurations.agent-sandbox-${host}.config.microvm.declaredRunner";

  opencodeAliases = {
    opencode = "opencode-vm";
    opencode-local = lib.getExe config.home-manager.users.${config.user.name}.programs.opencode.package;
  };

  projectsDirectory = ''
    projects_dir="$HOME/projects"
    if [ ! -d "$projects_dir" ] && [ -d "$HOME/Projects" ]; then
      projects_dir="$HOME/Projects"
    fi
    if [ ! -d "$projects_dir" ]; then
      echo "Create ~/projects (or ~/Projects) before starting the VM." >&2
      exit 2
    fi
    projects_dir="$(cd "$projects_dir" && pwd -P)"
  '';

  opencode-vm = pkgs.writeShellScriptBin "opencode-vm" ''
    set -euo pipefail
    ${projectsDirectory}
    current_dir="$(pwd -P)"

    case "$current_dir" in
      "$projects_dir")
        relative=""
        ;;
      "$projects_dir/"*)
        relative="''${current_dir#"$projects_dir"}"
        ;;
      *)
        echo "opencode-vm must be run under $projects_dir" >&2
        exit 2
        ;;
    esac

    ${microvm}/bin/microvm start
    guest_address="$(${microvm}/bin/microvm address)"
    exec ${lib.getExe pkgs.opencode} attach "http://$guest_address:${toString opencodePort}" \
      --dir "/root/projects$relative" "$@"
  '';

  microvm = pkgs.writeShellScriptBin "microvm" ''
    set -euo pipefail
    umask 077

    statedir="$HOME/.local/share/microvm"
    pidfile="$statedir/vfkit.pid"
    logfile="$statedir/vfkit.log"
    lockfile="$statedir/launch.lock"
    control_socket="$statedir/control.sock"

    usage() {
      echo "Usage: microvm <start|run|stop|restart|status|address|logs|help>"
      echo "start: background; run: foreground; stop: graceful shutdown (120s timeout)"
    }

    running() {
      [ -r "$pidfile" ] || return 1
      IFS= read -r pid < "$pidfile"
      [[ "$pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$pid" 2>/dev/null || return 1
      command="$(/bin/ps -p "$pid" -o command= 2>/dev/null)" || return 1
      case "$command" in
        *vfkit*|*microvm-run*|*microvm@agent-sandbox*) return 0 ;;
        *) return 1 ;;
      esac
    }

    locked() {
      [ -e "$lockfile" ] && ! ${lib.getExe pkgs.flock} -n "$lockfile" true
    }

    resolve_address() {
      guest_address="''${MICROVM_GUEST_ADDRESS:-}"
      if [ -z "$guest_address" ] && [ -r /var/db/dhcpd_leases ]; then
        guest_address="$(${lib.getExe pkgs.gawk} -F= -v wanted="${guestMac}" '
          function normalize(mac, parts, count, i, result) {
            sub(/^[^,]*,/, "", mac)
            count = split(mac, parts, ":")
            if (count != 6) return ""
            for (i = 1; i <= count; i++) {
              if (parts[i] !~ /^[0-9a-fA-F]{1,2}$/) return ""
              result = result (i == 1 ? "" : ":") sprintf("%02x", strtonum("0x" parts[i]))
            }
            return result
          }
          /^[[:space:]]*[{]/ { mac = ""; ip = "" }
          { gsub(/[[:space:]]/, "", $1); gsub(/[[:space:]]/, "", $2) }
          $1 == "hw_address" { mac = normalize($2) }
          $1 == "ip_address" { ip = $2 }
          /^[[:space:]]*[}]/ { if (mac == wanted) address = ip }
          END { print address }
        ' /var/db/dhcpd_leases)"
      fi
      [[ "$guest_address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
      local octet
      local -a octets
      IFS=. read -r -a octets <<< "$guest_address"
      for octet in "''${octets[@]}"; do
        ((10#$octet <= 255)) || return 1
      done
    }

    healthy() {
      resolve_address || return 1
      ${lib.getExe pkgs.curl} --fail --silent --noproxy '*' --connect-timeout 1 --max-time 2 \
        "http://$guest_address:${toString opencodePort}/global/health" >/dev/null
    }

    request_stop() {
      ${lib.getExe pkgs.curl} --fail --silent --show-error --noproxy '*' \
        --connect-timeout 1 --max-time 5 --unix-socket "$control_socket" \
        --header 'Content-Type: application/json' \
        --data '{"state":"Stop"}' http://localhost/vm/state
    }

    private_state() {
      mkdir -p "$statedir"
      chmod 0700 "$statedir"
      for file in "$statedir"/*.img "$pidfile" "$logfile" "$lockfile"; do
        if [ -f "$file" ]; then
          chmod 0600 "$file"
        fi
      done
    }

    validate_path() {
      # Upstream expands runtime arguments with word splitting and globbing.
      case "$1" in
        ""|*[!a-zA-Z0-9_./-]*)
          echo "Unsupported VM host path: $1 (use ASCII letters, digits, /, ., _, -)" >&2
          exit 2
          ;;
      esac
    }

    run_runner() {
      runner="$1"
      agent_secrets_dir=""
      saved_tty=""
      cleanup() {
        if [ -n "$agent_secrets_dir" ] && ! running; then
          rm -rf -- "$agent_secrets_dir"
        fi
        if [ -n "$saved_tty" ]; then
          stty "$saved_tty"
        fi
      }
      trap cleanup EXIT
      trap 'exit 1' HUP INT TERM

      if [ -t 0 ]; then
        saved_tty="$(stty -g)"
        stty intr undef quit undef susp undef
      fi

      secret_file="${flakeRef}/secrets/agent.sops.env"
      if [ -f "$secret_file" ]; then
        agent_secrets_dir="$(mktemp -d "$statedir/agent-secrets.XXXXXX")"
        SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}" \
          ${lib.getExe pkgs.sops} decrypt "$secret_file" > "$agent_secrets_dir/opencode.env"
        chmod 0400 "$agent_secrets_dir/opencode.env"
      else
        echo "No agent credentials configured; OpenCode will not start." >&2
      fi

      AGENT_PROJECTS_DIR="$projects_dir" AGENT_SECRETS_DIR="$agent_secrets_dir" \
        AGENT_CONTROL_SOCKET="$control_socket" "$runner/bin/microvm-run"
    }

    prepare() {
      ${projectsDirectory}
      validate_path "$projects_dir"
      validate_path "$statedir"
      if [ "''${#control_socket}" -gt 103 ]; then
        echo "VM control socket path exceeds macOS's 103-byte limit: $control_socket" >&2
        exit 2
      fi
      if running; then
        echo "agent-sandbox is already running (PID $pid)." >&2
        return 1
      fi
      rm -f "$pidfile" "$control_socket"

      echo "Building/substituting agent-sandbox micro VM for ${host}..." >&2
      runner="$statedir/runner"
      ${lib.getExe pkgs.nix} build --out-link "$runner" \
        "${flakeRef}#${runnerAttr}"
      cd "$statedir"
    }

    case "''${1:-help}" in
      start)
        private_state
        launcher_pid=""
        deadline=$((SECONDS + 120))
        while ((SECONDS < deadline)); do
          if running && healthy; then
            echo "agent-sandbox is ready (PID $pid, $guest_address)." >&2
            exit 0
          fi
          if [ -n "$launcher_pid" ] && ! kill -0 "$launcher_pid" 2>/dev/null; then
            launch_status=0
            wait "$launcher_pid" || launch_status=$?
            launcher_pid=""
            # A competing launch (or a brief status probe) may have won the lock.
            if [ "$launch_status" -ne 75 ]; then
              echo "agent-sandbox failed to start; see $logfile" >&2
              exit 1
            fi
          fi
          if [ -z "$launcher_pid" ] && ! running && ! locked; then
            # Lock before script opens the log or prepares images; hold until exit.
            ${lib.getExe' pkgs.coreutils "nohup"} ${lib.getExe pkgs.flock} -n -E 75 "$lockfile" \
              /usr/bin/script -q "$logfile" "$0" _run \
              </dev/null >/dev/null 2>&1 &
            launcher_pid=$!
          fi
          sleep 1
        done
        echo "OpenCode was not ready within 120 seconds; the VM/build may still be running." >&2
        echo "Use microvm status/logs to diagnose, or microvm stop once the VM is running." >&2
        echo "If DHCP discovery is unavailable, set MICROVM_GUEST_ADDRESS to the guest IPv4 address." >&2
        exit 1
        ;;
      run)
        private_state
        launch_status=0
        ${lib.getExe pkgs.flock} -w 1 -E 75 "$lockfile" "$0" _run || launch_status=$?
        if [ "$launch_status" -eq 75 ]; then
          echo "agent-sandbox is already running or a launch is in progress." >&2
        fi
        exit "$launch_status"
        ;;
      _run)
        [ "$#" -eq 1 ] || exit 2
        prepare
        run_runner "$runner"
        ;;
      stop)
        if ! running; then
          if locked; then
            echo "A VM launch or cleanup is in progress; retry when it finishes." >&2
            exit 1
          fi
          echo "agent-sandbox is not running." >&2
          rm -f "$pidfile"
          exit 0
        fi
        if [ ! -S "$control_socket" ]; then
          echo "No VM control socket; use guest poweroff (older runners need this once after upgrading)." >&2
          exit 1
        fi
        # vfkit can exit before its REST response is flushed.
        if ! request_stop; then
          echo "No shutdown acknowledgement; checking whether the VM exits." >&2
        fi
        deadline=$((SECONDS + 120))
        while ((SECONDS < deadline)); do
          if ! running && ! locked; then
            break
          fi
          sleep 1
        done
        if running || locked; then
          echo "Shutdown timed out; no automatic force-stop. Inspect logs or use guest poweroff." >&2
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
          if locked; then
            echo "agent-sandbox is starting or cleaning up"
            exit 2
          fi
          echo "agent-sandbox is stopped"
          exit 1
        fi
        if healthy; then
          echo "agent-sandbox is running (PID $pid, $guest_address, OpenCode healthy)"
        else
          echo "agent-sandbox is running (PID $pid, OpenCode unavailable)"
          exit 2
        fi
        ;;
      address)
        if ! running || ! resolve_address; then
          echo "No address found for a running agent-sandbox; check DHCP or MICROVM_GUEST_ADDRESS." >&2
          exit 1
        fi
        echo "$guest_address"
        ;;
      logs)
        private_state
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
    disable to free the builder VM's resources (disabling deletes its state)
  '';

  config = {
    environment.systemPackages = [ microvm opencode-vm ];
    hm.programs = {
      fish.shellAliases = opencodeAliases;
      zsh.shellAliases = opencodeAliases;
    };
    nix = lib.mkIf cfg.enable {
      distributedBuilds = true;
      # Keep the stock cached builder so a fresh Mac can bootstrap it.
      linux-builder.enable = true;
    };
  };
}
