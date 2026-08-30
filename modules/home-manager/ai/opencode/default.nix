{ lib, config, pkgs, ... }:
let
  name = "opencode";
  cfg = config.${name};

  google-skills = pkgs.fetchFromGitHub {
    owner = "google";
    repo = "skills";
    rev = "cdbd650dfefa4f3cba7ccf05f9fa8f746ba47282"; # main;
    sha256 = "sha256-6My0Hyf9nYsiSF8hKfjJSW/JeIG1OWymzzNmMEmo/oA=";
  };

  go-modern-guidelines = pkgs.fetchFromGitHub {
    owner = "JetBrains";
    repo = "go-modern-guidelines";
    rev = "c17350498ae6a8f50e0d3882cd0d7fc132b5a233"; # main
    sha256 = "0y8pvfp9qmygf1kdhzzcd1xnbminpmg3i6drkmx5jcdbdfya7n3l";
  };

  stop-slop = pkgs.fetchFromGitHub {
    owner = "hardikpandya";
    repo = "stop-slop";
    rev = "8da1f030185bdfe8471220585162991eaeb970e9"; # main
    sha256 = "08adzwqls4r1byvafpr6z42y8fcvvachxk1jsl3gq0a42l4sbji4";
  };

  inherit (lib) mkIf mkEnableOption;

  # Flip an otherwise-"ask" bash/skill/external-directory rule to "allow"
  # when opencode.sandboxed is set (see options.opencode.sandboxed above).
  sb = v: if config.opencode.sandboxed then "allow" else v;
in
{
  options.${name} = {
    enable = mkEnableOption name;
    sandboxed = mkEnableOption ''
      assume opencode is running inside an isolated execution environment
      (e.g. the agent-sandbox microVM), and relax bash/skill/external-directory
      permission prompts that only guard against unrestrained *host* execution.
      Rules protecting live repo state (git, rm) and secrets (read denies)
      still apply, since those risks aren't mitigated by the sandbox boundary
    '';
  };

  config = mkIf cfg.enable {
    catppuccin.opencode.enable = true;

    programs = {
      ripgrep.enable = true; # dependency
      opencode = {
        enable = true;
        enableMcpIntegration = true;

        skills = {
          alloydb-basics = "${google-skills}/skills/cloud/alloydb-basics";
          bigquery-basics = "${google-skills}/skills/cloud/bigquery-basics";
          cloud-run-basics = "${google-skills}/skills/cloud/cloud-run-basics";
          gke-basics = "${google-skills}/skills/cloud/gke-basics";
          stop-slop = "${stop-slop}";
          # TODO, this is now a weird cli and not a raw skill file based repo
          # use-modern-go = "${go-modern-guidelines}/claude/modern-go-guidelines/skills/use-modern-go";
        };

        tui.scroll_acceleration.enabled = true; # Enable macOS-style smooth scroll acceleration

        settings = {
          lsp = true; # todo gopls on mod and sum?

          # https://github.com/wimpysworld/nix-config/blob/4ce6c0e6afffcd6586306cd92499c4fb62efe749/home-manager/_mixins/development/opencode/default.nix
          permission = {
            # Safe operations - allow without prompting
            # CRITICAL: Deny rules must be LAST due to .findLast() matching
            read = {
              # ALLOW: Default allow most file reads (FIRST - lowest priority)
              "*" = "allow";
              "**/*" = "allow";

              # ══════════════════════════════════════════════════════════════
              # DENY: Credentials and secrets (LAST - highest priority)
              # These must come after the allow rules due to .findLast()
              # ══════════════════════════════════════════════════════════════

              # Environment files
              ".env" = "deny";
              ".env.*" = "deny";
              "**/env.go" = "allow";
              ".env.local" = "deny";
              ".env.*.local" = "deny";

              # Secrets
              "**/secrets/**" = "deny";
              "**/.secrets/**" = "deny";
              "secrets/**" = "deny";
              ".secrets/**" = "deny";
              "*secret*" = "deny";

              # SSH keys (fully qualified + patterns)
              "${config.home.homeDirectory}/.ssh/**" = "deny";
              "**/id_rsa" = "deny";
              "**/id_rsa.*" = "deny";
              "**/id_ed25519" = "deny";
              "**/id_ed25519.*" = "deny";
              "**/id_ecdsa" = "deny";
              "**/id_ecdsa.*" = "deny";
              "**/*_rsa" = "deny";
              "**/*_rsa.*" = "deny";
              "**/*_ed25519" = "deny";
              "**/*_ed25519.*" = "deny";
              "**/*_ecdsa" = "deny";
              "**/*_ecdsa.*" = "deny";

              # Various keys
              "*.pem" = "deny";
              "*.pem*" = "deny";
              "*.key" = "deny";
              "*.key*" = "deny";
              "*.pk" = "deny";
              "*.pk*" = "deny";
              "*.crt" = "deny";
              "*.crt*" = "deny";
              "*.csr" = "deny";
              "*.csr*" = "deny";
              "*.cer" = "deny";
              "*.cer*" = "deny";
              "*sftp*" = "deny";

              # GPG keys
              "${config.home.homeDirectory}/.gnupg/**" = "deny";

              # Cloud credentials
              "${config.home.homeDirectory}/.aws/**" = "deny";
              "${config.home.homeDirectory}/.azure/**" = "deny";
              "${config.xdg.configHome}/gcloud/**" = "deny";

              # VCS credentials
              "${config.xdg.configHome}/gh/hosts.yml" = "deny";

              # Container/Kubernetes secrets
              "${config.home.homeDirectory}/.docker/config.json" = "deny";
              "${config.home.homeDirectory}/.kube/**" = "deny";
              "${config.xdg.dataHome}/kube/**" = "deny";

              # Shell history (may contain passwords)
              "${config.home.homeDirectory}/.bash_history" = "deny";
              "${config.home.homeDirectory}/.zsh_history" = "deny";
              "${config.home.homeDirectory}/.fish_history" = "deny";
              "${config.xdg.dataHome}/fish/fish_history" = "deny";
            };
            glob = "allow"; # Finding files by pattern
            grep = "allow"; # Searching file contents
            list = "allow"; # Listing directories
            todoread = "allow"; # Reading todo lists
            lsp = "allow"; # Language server queries
            # Potentially destructive operations - require approval
            edit = "allow"; # All file modifications (edit, write, patch)
            bash = {
              # ══════════════════════════════════════════════════════════════
              # Shell - read-only utilities (safe with any arguments)
              # ══════════════════════════════════════════════════════════════
              "ls" = "allow";
              "ls *" = "allow";
              "cat" = "allow";
              "cat *" = "allow";
              "head" = "allow";
              "head *" = "allow";
              "tail" = "allow";
              "tail *" = "allow";
              "wc" = "allow";
              "wc *" = "allow";
              "file" = "allow";
              "file *" = "allow";
              "tree" = "allow";
              "tree *" = "allow";
              "pwd" = "allow";
              "which" = "allow";
              "which *" = "allow";
              "type" = "allow";
              "type *" = "allow";
              "env" = "allow";
              "fd" = "allow";
              "fd *" = "allow";
              "rg" = "allow";
              "rg *" = "allow";
              "grep" = "allow";
              "grep *" = "allow";
              "egrep *" = "allow";
              "fgrep *" = "allow";
              "mkdir" = sb "ask";
              "mkdir *" = sb "ask";
              "touch" = sb "ask";
              "touch *" = sb "ask";
              "whoami" = "allow";
              "hostname" = "allow";
              "hostname *" = "allow";
              "uname" = "allow";
              "uname *" = "allow";
              "df" = "allow";
              "df *" = "allow";
              "free" = "allow";
              "free *" = "allow";
              "ps" = "allow";
              "ps *" = "allow";
              "top -b*" = "allow";
              "uptime" = "allow";
              "date" = "allow";
              "date *" = "allow";
              "lscpu" = "allow";
              "lscpu *" = "allow";
              "lsblk" = "allow";
              "lsblk *" = "allow";
              "lsusb" = "allow";
              "lsusb *" = "allow";
              "lspci" = "allow";
              "lspci *" = "allow";
              "id" = "allow";
              "id *" = "allow";
              "groups" = "allow";
              "groups *" = "allow";
              "printenv" = "allow";
              "printenv *" = "allow";
              "basename *" = "allow";
              "dirname *" = "allow";
              "realpath *" = "allow";
              "stat" = "allow";
              "stat *" = "allow";
              "du" = "allow";
              "du *" = "allow";
              "sort" = "allow";
              "sort *" = "allow";
              "uniq" = "allow";
              "uniq *" = "allow";
              "cut" = "allow";
              "cut *" = "allow";
              "awk" = "allow";
              "awk *" = "allow";
              "diff" = "allow";
              "diff *" = "allow";
              "cmp" = "allow";
              "cmp *" = "allow";
              "less *" = "allow";
              "more *" = "allow";
              "tr *" = "allow";
              "tac" = "allow";
              "tac *" = "allow";
              "rev" = "allow";
              "rev *" = "allow";
              "seq *" = "allow";
              "md5sum *" = "allow";
              "sha256sum *" = "allow";
              "shasum *" = "allow";
              "jq" = "allow";
              "jq *" = "allow";
              "yq" = "allow";
              "yq *" = "allow";
              "bc" = "allow";
              "bc *" = "allow";
              "man *" = "allow";
              "tldr *" = "allow";
              "strings *" = "allow";
              "test *" = "allow";
              "true" = "allow";
              "false" = "allow";
              "sleep *" = "allow";

              # Text processing - additional
              "column *" = "allow";
              "fold *" = "allow";
              "nl *" = "allow";
              "pr *" = "allow";
              "expand *" = "allow";
              "unexpand *" = "allow";
              "paste *" = "allow";
              "join *" = "allow";
              "comm *" = "allow";

              # Archive inspection (read-only)
              "tar -t*" = "allow";
              "tar --list*" = "allow";
              "unzip -l*" = "allow";
              "zipinfo *" = "allow";
              "7z l*" = "allow";
              "zcat *" = "allow";
              "bzcat *" = "allow";
              "xzcat *" = "allow";
              "zless *" = "allow";
              "bzless *" = "allow";
              "xzless *" = "allow";

              # Network inspection (read-only)
              "ip addr" = "allow";
              "ip addr show*" = "allow";
              "ip link show*" = "allow";
              "ip route show*" = "allow";
              "ss -t*" = "allow";
              "ss -u*" = "allow";
              "ss -l*" = "allow";
              "netstat -t*" = "allow";
              "netstat -l*" = "allow";
              "ping -c*" = "allow";
              "traceroute *" = "allow";
              "dig *" = "allow";
              "host *" = "allow";
              "nslookup *" = "allow";

              # Process inspection
              "pgrep *" = "allow";
              "pidof *" = "allow";
              "pstree *" = "allow";
              "lsof -p*" = "allow";
              "lsof *" = "allow";

              # Alternative file viewers
              "bat" = "allow";
              "bat *" = "allow";
              "most *" = "allow";

              # Development helpers
              "xxd *" = "allow";
              "hexdump *" = "allow";
              "od *" = "allow";
              "base64 *" = "allow";
              "base32 *" = "allow";
              "shellcheck *" = "allow";
              "shfmt --diff *" = "allow";
              "shfmt -d *" = "allow";
              "luacheck *" = "allow";

              # Shell - ask: file modification or redirection risk
              "xdg-open *" = sb "ask";
              "sed" = sb "ask";
              "sed *" = sb "ask";
              "sd *" = sb "ask";
              "mv *" = sb "ask";
              "cp *" = sb "ask";
              "tee *" = sb "ask";
              "echo *" = sb "ask";
              "printf *" = sb "ask";
              "curl *" = sb "ask";
              "wget *" = sb "ask";
              "chmod *" = sb "ask";
              "chown *" = sb "ask";
              "kill *" = sb "ask";
              "pkill *" = sb "ask";
              "ln *" = sb "ask";

              # ══════════════════════════════════════════════════════════════
              # Systemd - deny power management first
              # ══════════════════════════════════════════════════════════════
              "systemctl poweroff*" = "deny";
              "systemctl reboot*" = "deny";
              "systemctl halt*" = "deny";
              "systemctl suspend*" = "deny";
              "systemctl hibernate*" = "deny";
              "systemctl rescue*" = "deny";
              "systemctl emergency*" = "deny";

              # Systemd - read-only status and log queries
              "systemctl --version" = "allow";
              "systemctl status" = "allow";
              "systemctl status *" = "allow";
              "systemctl is-active *" = "allow";
              "systemctl is-enabled *" = "allow";
              "systemctl is-failed *" = "allow";
              "systemctl list-units" = "allow";
              "systemctl list-units *" = "allow";
              "systemctl list-unit-files" = "allow";
              "systemctl list-unit-files *" = "allow";
              "systemctl list-dependencies *" = "allow";
              "systemctl list-jobs" = "allow";
              "systemctl list-jobs *" = "allow";
              "systemctl list-sockets*" = "allow";
              "systemctl list-timers*" = "allow";
              "systemctl show *" = "allow";
              "systemctl cat *" = "allow";
              "systemctl help *" = "allow";
              "journalctl" = "allow";
              "journalctl *" = "allow";
              "systemd-analyze" = "allow";
              "systemd-analyze *" = "allow";
              "hostnamectl" = "allow";
              "hostnamectl *" = "allow";
              "timedatectl" = "allow";
              "timedatectl *" = "allow";
              "loginctl" = "allow";
              "loginctl *" = "allow";
              "localectl" = "allow";
              "localectl *" = "allow";
              "networkctl" = "allow";
              "networkctl *" = "allow";
              "resolvectl" = "allow";
              "resolvectl *" = "allow";
              "busctl" = "allow";
              "busctl *" = "allow";
              "coredumpctl" = "allow";
              "coredumpctl *" = "allow";

              # Systemd - ask: service state modifications
              "systemctl start *" = sb "ask";
              "systemctl stop *" = sb "ask";
              "systemctl restart *" = sb "ask";
              "systemctl reload *" = sb "ask";
              "systemctl enable *" = sb "ask";
              "systemctl disable *" = sb "ask";
              "systemctl mask *" = sb "ask";
              "systemctl unmask *" = sb "ask";
              "systemctl daemon-reload" = sb "ask";
              "systemctl daemon-reexec" = sb "ask";
              "systemctl edit *" = sb "ask";
              "systemctl set-property *" = sb "ask";

              # ══════════════════════════════════════════════════════════════
              # Docker - deny mass destruction first
              # ══════════════════════════════════════════════════════════════
              "docker rm *" = "deny";
              "docker rmi *" = "deny";
              "docker system prune*" = "deny";
              "docker volume prune*" = "deny";
              "docker container prune*" = "deny";
              "docker image prune*" = "deny";
              "docker network prune*" = "deny";
              "docker volume rm *" = "deny";
              "docker network rm *" = "deny";

              # Docker - read-only queries
              "docker --version" = "allow";
              "docker version" = "allow";
              "docker info" = "allow";
              "docker ps" = "allow";
              "docker ps *" = "allow";
              "docker images" = "allow";
              "docker images *" = "allow";
              "docker logs *" = "allow";
              "docker inspect *" = "allow";
              "docker stats" = "allow";
              "docker stats *" = "allow";
              "docker network ls" = "allow";
              "docker network ls *" = "allow";
              "docker network inspect *" = "allow";
              "docker volume ls" = "allow";
              "docker volume ls *" = "allow";
              "docker volume inspect *" = "allow";
              "docker top *" = "allow";
              "docker port *" = "allow";
              "docker diff *" = "allow";
              "docker history *" = "allow";
              "docker search *" = "allow";
              "docker-compose --version" = "allow";
              "docker-compose config*" = "allow";
              "docker compose --version" = "allow";
              "docker compose config*" = "allow";

              # Docker - ask: container operations
              "docker build *" = sb "ask";
              "docker run *" = sb "ask";
              "docker exec *" = sb "ask";
              "docker stop *" = sb "ask";
              "docker start *" = sb "ask";
              "docker restart *" = sb "ask";
              "docker kill *" = sb "ask";
              "docker pause *" = sb "ask";
              "docker unpause *" = sb "ask";
              "docker pull *" = sb "ask";
              "docker push *" = "ask"; # affects remote registry state - always ask
              "docker tag *" = "ask"; # often precedes a push - always ask
              "docker create *" = sb "ask";
              "docker commit *" = sb "ask";
              "docker cp *" = sb "ask";
              "docker-compose up*" = sb "ask";
              "docker-compose down*" = sb "ask";
              "docker compose up*" = sb "ask";
              "docker compose down*" = sb "ask";

              # ══════════════════════════════════════════════════════════════
              # Build tools - version checks and read-only inspection
              # ══════════════════════════════════════════════════════════════
              "autoconf --version" = "allow";
              "automake --version" = "allow";
              "make --version" = "allow";
              "make -n*" = "allow";
              "cmake --version" = "allow";
              "cmake -E capabilities" = "allow";
              "meson --version" = "allow";
              "ninja --version" = "allow";
              "clang --version" = "allow";
              "clang++ --version" = "allow";
              "clang-tidy --version" = "allow";
              "clang-format --version" = "allow";
              "clangd --version" = "allow";
              "gcc --version" = "allow";
              "g++ --version" = "allow";
              "ldd" = "allow";
              "ldd *" = "allow";
              "pkg-config *" = "allow";
              "pkgconf *" = "allow";
              "ar --version" = "allow";
              "ranlib --version" = "allow";
              "objdump" = "allow";
              "objdump *" = "allow";
              "nm" = "allow";
              "nm *" = "allow";
              "readelf" = "allow";
              "readelf *" = "allow";

              # Build tools - ask: configuration and builds
              "./configure*" = sb "ask";
              "configure *" = sb "ask";
              "autoreconf*" = sb "ask";
              "autoconf *" = sb "ask";
              "automake *" = sb "ask";
              "make" = sb "ask";
              "make *" = sb "ask";
              "cmake *" = sb "ask";
              "meson *" = sb "ask";
              "ninja" = sb "ask";
              "ninja *" = sb "ask";
              "clang *" = sb "ask";
              "clang++ *" = sb "ask";
              "gcc *" = sb "ask";
              "g++ *" = sb "ask";
              "ar *" = sb "ask";
              "ranlib *" = sb "ask";
              "clang-tidy *" = sb "ask";
              "clang-format *" = sb "ask";

              # ══════════════════════════════════════════════════════════════
              # GitHub CLI - deny destructive first
              # ══════════════════════════════════════════════════════════════
              "gh repo delete*" = "deny";
              "gh release delete*" = "deny";
              "gh gist delete*" = "deny";

              # GitHub CLI - read-only queries
              "gh --version" = "allow";
              "gh auth status*" = "allow";
              "gh status" = "allow";
              "gh status *" = "allow";
              "gh repo view*" = "allow";
              "gh repo list*" = "allow";
              "gh pr view*" = "allow";
              "gh pr list*" = "allow";
              "gh pr status*" = "allow";
              "gh pr diff*" = "allow";
              "gh pr checks*" = "allow";
              "gh issue view*" = "allow";
              "gh issue list*" = "allow";
              "gh issue status*" = "allow";
              "gh run view*" = "allow";
              "gh run list*" = "allow";
              "gh workflow view*" = "allow";
              "gh workflow list*" = "allow";
              "gh release view*" = "allow";
              "gh release list*" = "allow";
              "gh gist view*" = "allow";
              "gh gist list*" = "allow";
              "gh api *" = "allow";
              "gh search *" = "allow";

              # GitHub CLI - ask: state modifications
              "gh pr create*" = "ask";
              "gh pr merge*" = "ask";
              "gh pr close*" = "ask";
              "gh pr reopen*" = "ask";
              "gh pr checkout*" = "ask";
              "gh pr review*" = "ask";
              "gh pr edit*" = "ask";
              "gh pr comment*" = "ask";
              "gh issue create*" = "ask";
              "gh issue close*" = "ask";
              "gh issue reopen*" = "ask";
              "gh issue edit*" = "ask";
              "gh issue comment*" = "ask";
              "gh repo create*" = "ask";
              "gh repo clone*" = "ask";
              "gh repo fork*" = "ask";
              "gh repo edit*" = "ask";
              "gh release create*" = "ask";
              "gh release edit*" = "ask";
              "gh run rerun*" = "ask";
              "gh run cancel*" = "ask";
              "gh workflow run*" = "ask";
              "gh gist create*" = "ask";
              "gh gist edit*" = "ask";

              # ══════════════════════════════════════════════════════════════
              # Git - deny destructive first
              # ══════════════════════════════════════════════════════════════
              "git reset --hard*" = "deny";
              "git clean*" = "deny";
              "git filter-branch*" = "deny";
              "git filter-repo*" = "deny";
              "git reflog expire*" = "deny";

              # Git - read-only queries
              "git status" = "allow";
              "git status *" = "allow";
              "git diff" = "allow";
              "git diff *" = "allow";
              "git log" = "allow";
              "git log *" = "allow";
              "git show" = "allow";
              "git show *" = "allow";
              "git branch" = "allow";
              "git branch -a*" = "allow";
              "git branch -v*" = "allow";
              "git branch -r*" = "allow";
              "git branch --list*" = "allow";
              "git branch --contains*" = "allow";
              "git branch --merged*" = "allow";
              "git branch --no-merged*" = "allow";
              "git remote" = "allow";
              "git remote *" = "allow";
              "git tag" = "allow";
              "git tag -l*" = "allow";
              "git tag --list*" = "allow";
              "git stash list*" = "allow";
              "git stash show*" = "allow";
              "git reflog" = "allow";
              "git reflog *" = "allow";
              "git rev-parse *" = "allow";
              "git describe *" = "allow";
              "git shortlog *" = "allow";
              "git blame *" = "allow";
              "git ls-files" = "allow";
              "git ls-files *" = "allow";
              "git ls-tree *" = "allow";
              "git ls-remote *" = "allow";
              "git grep *" = "allow";
              "git config --list*" = "allow";
              "git config --get*" = "allow";
              "git worktree list" = "allow";
              "git name-rev *" = "allow";
              "git cat-file *" = "allow";
              "git count-objects*" = "allow";
              "git for-each-ref *" = "allow";
              "git symbolic-ref *" = "allow";
              "git verify-commit *" = "allow";
              "git verify-tag *" = "allow";

              # Git - ask: state modifications
              "git add *" = "ask";
              "git commit" = "ask";
              "git commit *" = "ask";
              "git push" = "ask";
              "git push *" = "ask";

              # Force push - explicit deny (must come AFTER general push patterns)
              "git push*--force*" = "deny";
              "git push*-f *" = "deny";
              "git push * --force*" = "deny";
              "git push * -f*" = "deny";

              "git pull" = "ask";
              "git pull *" = "ask";
              "git fetch" = "ask";
              "git fetch *" = "ask";
              "git checkout *" = "ask";
              "git switch *" = "ask";
              "git branch -d *" = "ask";
              "git branch -D *" = "ask";
              "git branch -m *" = "ask";
              "git branch -M *" = "ask";
              "git branch --set-upstream*" = "ask";
              "git branch *" = "ask";
              "git merge *" = "ask";
              "git rebase *" = "ask";
              "git cherry-pick *" = "ask";
              "git stash" = "ask";
              "git stash *" = "ask";
              "git restore *" = "ask";
              "git reset *" = "ask";
              "git revert *" = "ask";
              "git tag -a *" = "ask";
              "git tag -d *" = "ask";
              "git tag -s *" = "ask";
              "git tag *" = "ask";
              "git worktree add *" = "ask";
              "git worktree remove *" = "ask";
              "git worktree prune*" = "ask";
              "git am *" = "ask";
              "git apply *" = "ask";
              "git bisect *" = "ask";
              "git clone *" = "ask";
              "git config *" = "ask";
              "git init*" = "ask";
              "git mv *" = "ask";
              "git rm *" = "ask";
              "git submodule *" = "ask";

              # ══════════════════════════════════════════════════════════════
              # Nix - deny garbage collection first
              # ══════════════════════════════════════════════════════════════
              "nix-collect-garbage" = "deny";
              "nix-collect-garbage *" = "deny";
              "nix store gc*" = "deny";
              "nix store delete*" = "deny";

              # Nix - read-only info and evaluation
              "nix --version" = "allow";
              "nix flake show*" = "allow";
              "nix flake check*" = "allow";
              "nix flake metadata*" = "allow";
              "nix flake info*" = "allow";
              "nix eval *" = "allow";
              "nix search *" = "allow";
              "nix path-info *" = "allow";
              "nix why-depends *" = "allow";
              "nix derivation show *" = "allow";
              "nix store ls *" = "allow";
              "nix hash *" = "allow";
              "nix-instantiate" = "allow";
              "nix-instantiate *" = "allow";
              "nix repl" = "allow";
              "nix repl *" = "allow";
              "nix log *" = "allow";
              "nix show-config" = "allow";
              "nix show-config *" = "allow";
              "nix doctor" = "allow";
              "nix store verify *" = "allow";
              "nix-store --query *" = "allow";
              "nix-store -q *" = "allow";
              "nixfmt" = "allow";
              "nixfmt *" = "allow";
              "statix *" = "allow";
              "deadnix *" = "allow";
              "alejandra *" = "allow";

              # Nix - ask: builds and environment changes
              "nix build*" = sb "ask";
              "nix develop*" = sb "ask";
              "nix run *" = sb "ask";
              "nix shell *" = sb "ask";
              "nix flake update*" = sb "ask";
              "nix flake lock*" = sb "ask";
              "nix profile *" = sb "ask";
              "nix-shell" = sb "ask";
              "nix-shell *" = sb "ask";
              "nix-build *" = sb "ask";
              "nix-env *" = sb "ask";
              "home-manager *" = sb "ask";
              "nixos-rebuild *" = sb "ask";
              "darwin-rebuild *" = sb "ask";

              # ══════════════════════════════════════════════════════════════
              # Go
              # ══════════════════════════════════════════════════════════════
              "go version" = "allow";
              "go env" = "allow";
              "go env *" = "allow";
              "go list *" = "allow";
              "go vet" = "allow";
              "go vet *" = "allow";
              "go doc *" = "allow";
              "go mod graph" = "allow";
              "go mod graph *" = "allow";
              "go mod why *" = "allow";
              "go mod verify" = "allow";
              "go mod download" = "allow";
              "go mod download *" = "allow";
              "go help *" = "allow";
              "go test*" = "allow";

              "go build*" = sb "ask";
              "go run *" = sb "ask";
              "go generate*" = sb "ask";
              "go get *" = sb "ask";
              "go install *" = sb "ask";
              "go mod tidy*" = sb "ask";
              "go mod init*" = sb "ask";
              "go mod edit*" = sb "ask";
              "go work *" = sb "ask";
              "go fmt *" = sb "ask";
              "gofmt *" = sb "ask";

              # ══════════════════════════════════════════════════════════════
              # JavaScript/TypeScript - deny cache corruption first
              # ══════════════════════════════════════════════════════════════
              "npm cache clean --force*" = "deny";
              "npm cache clean -f*" = "deny";
              "pnpm store prune*" = "deny";
              "yarn cache clean*" = "deny";

              # JavaScript/TypeScript - read-only
              "node --version" = "allow";
              "node -v" = "allow";
              "npm --version" = "allow";
              "npm -v" = "allow";
              "npm ls" = "allow";
              "npm ls *" = "allow";
              "npm list *" = "allow";
              "npm outdated" = "allow";
              "npm outdated *" = "allow";
              "npm view *" = "allow";
              "npm info *" = "allow";
              "npm search *" = "allow";
              "npm explain *" = "allow";
              "npm audit" = "allow";
              "npm audit *" = "allow";
              "npm doctor" = "allow";
              "npm config list*" = "allow";
              "npm config get*" = "allow";
              "npm help *" = "allow";
              "npm pack --dry-run*" = "allow";
              "npx --version" = "allow";

              "pnpm --version" = "allow";
              "pnpm -v" = "allow";
              "pnpm ls*" = "allow";
              "pnpm list*" = "allow";
              "pnpm outdated*" = "allow";
              "pnpm audit*" = "allow";
              "pnpm why *" = "allow";

              "yarn --version" = "allow";
              "yarn -v" = "allow";
              "yarn list*" = "allow";
              "yarn info *" = "allow";
              "yarn why *" = "allow";

              "tsc --version" = "allow";
              "tsc --noEmit*" = "allow";

              # JavaScript/TypeScript - ask: installs and execution
              "npm install*" = sb "ask";
              "npm i" = sb "ask";
              "npm i *" = sb "ask";
              "npm ci*" = sb "ask";
              "npm run *" = sb "ask";
              "npm test*" = sb "ask";
              "npm start*" = sb "ask";
              "npm exec *" = sb "ask";
              "npm publish*" = "ask"; # publishes to remote registry - always ask
              "npm uninstall*" = sb "ask";
              "npm update*" = sb "ask";
              "npm link*" = sb "ask";
              "npx *" = sb "ask";

              "pnpm install*" = sb "ask";
              "pnpm i" = sb "ask";
              "pnpm i *" = sb "ask";
              "pnpm run *" = sb "ask";
              "pnpm test*" = sb "ask";
              "pnpm exec *" = sb "ask";
              "pnpm dlx *" = sb "ask";
              "pnpm add *" = sb "ask";
              "pnpm remove *" = sb "ask";

              "yarn install*" = sb "ask";
              "yarn add *" = sb "ask";
              "yarn remove *" = sb "ask";
              "yarn run *" = sb "ask";

              "tsc" = sb "ask";
              "tsc *" = sb "ask";
              "vite*" = sb "ask";

              # ══════════════════════════════════════════════════════════════
              # Rust
              # ══════════════════════════════════════════════════════════════
              "cargo --version" = "allow";
              "cargo version" = "allow";
              "cargo check" = "allow";
              "cargo check *" = "allow";
              "cargo clippy" = "allow";
              "cargo clippy *" = "allow";
              "cargo doc" = "allow";
              "cargo doc *" = "allow";
              "cargo tree" = "allow";
              "cargo tree *" = "allow";
              "cargo metadata" = "allow";
              "cargo metadata *" = "allow";
              "cargo search *" = "allow";
              "cargo fmt --check*" = "allow";
              "cargo verify-project*" = "allow";
              "cargo locate-project*" = "allow";
              "cargo pkgid*" = "allow";
              "cargo read-manifest*" = "allow";
              "rustc --version" = "allow";
              "rustc --print *" = "allow";
              "rustup --version" = "allow";
              "rustup show*" = "allow";
              "rustup target list*" = "allow";
              "rustup component list*" = "allow";
              "rustup which *" = "allow";

              "cargo build*" = sb "ask";
              "cargo test*" = sb "ask";
              "cargo run*" = sb "ask";
              "cargo bench*" = sb "ask";
              "cargo install*" = sb "ask";
              "cargo uninstall*" = sb "ask";
              "cargo publish*" = "ask"; # publishes to remote registry - always ask
              "cargo update*" = sb "ask";
              "cargo add *" = sb "ask";
              "cargo remove *" = sb "ask";
              "cargo init*" = sb "ask";
              "cargo new *" = sb "ask";
              "cargo fmt" = sb "ask";
              "cargo fmt *" = sb "ask";
              "cargo fix*" = sb "ask";
              "cargo generate*" = sb "ask";
              "rustup update*" = sb "ask";
              "rustup default *" = sb "ask";
              "rustup toolchain *" = sb "ask";
              "rustup override *" = sb "ask";

              # ══════════════════════════════════════════════════════════════
              # Python
              # ══════════════════════════════════════════════════════════════
              "python --version" = "allow";
              "python -V" = "allow";
              "python3 --version" = "allow";
              "python3 -V" = "allow";
              "pip --version" = "allow";
              "pip -V" = "allow";
              "pip list" = "allow";
              "pip list *" = "allow";
              "pip show *" = "allow";
              "pip freeze" = "allow";
              "pip freeze *" = "allow";
              "pip check" = "allow";
              "pip index versions *" = "allow";
              "pip search *" = "allow";
              "pip help *" = "allow";

              "uv --version" = "allow";
              "uv pip list" = "allow";
              "uv pip list *" = "allow";
              "uv pip show *" = "allow";
              "uv pip freeze*" = "allow";
              "uv pip check*" = "allow";

              "pytest --version" = "allow";
              "pytest --collect-only*" = "allow";
              "python -m pytest --collect-only*" = "allow";
              "python3 -m pytest --collect-only*" = "allow";

              "mypy --version" = "allow";
              "ruff --version" = "allow";
              "ruff check" = "allow";
              "ruff check *" = "allow";
              "ruff rule *" = "allow";
              "black --version" = "allow";
              "black --check *" = "allow";
              "isort --version" = "allow";
              "isort --check*" = "allow";
              "isort --diff *" = "allow";

              "python" = sb "ask";
              "python *" = sb "ask";
              "python3" = sb "ask";
              "python3 *" = sb "ask";
              "pip install*" = sb "ask";
              "pip uninstall*" = sb "ask";
              "pip download*" = sb "ask";

              "uv pip install*" = sb "ask";
              "uv pip uninstall*" = sb "ask";
              "uv sync*" = sb "ask";
              "uv run *" = sb "ask";
              "uv venv*" = sb "ask";
              "uv lock*" = sb "ask";
              "uv add *" = sb "ask";
              "uv remove *" = sb "ask";

              "pytest" = sb "ask";
              "pytest *" = sb "ask";
              "python -m pytest*" = sb "ask";
              "python3 -m pytest*" = sb "ask";
              "mypy" = sb "ask";
              "mypy *" = sb "ask";
              "ruff" = sb "ask";
              "ruff *" = sb "ask";
              "black *" = sb "ask";
              "isort *" = sb "ask";

              # ══════════════════════════════════════════════════════════════
              # CATCH-ALL: Unknown commands require approval
              # Must come BEFORE deny rules in Nix, but will be processed
              # first by opencode's .findLast() matching
              # ══════════════════════════════════════════════════════════════
              "*" = "ask";

              # ══════════════════════════════════════════════════════════════
              # GLOBAL OVERRIDES - MUST BE LAST (highest priority with .findLast())
              # These rules match last and override earlier patterns
              # ══════════════════════════════════════════════════════════════

              # File deletion (supervised - prompts for confirmation)
              "rm" = "ask";
              "rm *" = "ask";
              "rmdir *" = "ask";

              # Destructive operations (denied - unrecoverable or bypass deletion)
              "dd *" = "deny";
              "shred *" = "deny";
              "wipe *" = "deny";
              "srm *" = "deny";
              "truncate *" = "deny";

              # Privilege escalation
              "sudo" = "deny";
              "sudo *" = "deny";

              # Subshell execution bypasses (arbitrary code execution)
              "bash -c*" = "deny";
              "sh -c*" = "deny";
              "fish -c*" = "deny";
              "zsh -c*" = "deny";
              "dash -c*" = "deny";

              # Direct code execution via interpreters
              "python -c*" = "deny";
              "python3 -c*" = "deny";
              "python2 -c*" = "deny";
              "node -e*" = "deny";
              "node --eval*" = "deny";
              "perl -e*" = "deny";
              "ruby -e*" = "deny";
              "lua -e*" = "deny";
              "php -r*" = "deny";

              # System modification
              "sysctl *" = "deny";
              "modprobe *" = "deny";
              "insmod *" = "deny";
              "rmmod *" = "deny";

              # Boot/firmware
              "grub-install *" = "deny";
              "update-grub *" = "deny";
              "efibootmgr *" = "deny";

              # Disk operations
              "fdisk *" = "deny";
              "parted *" = "deny";
              "gparted *" = "deny";
              "mkfs*" = "deny";
              "mkswap *" = "deny";
              "swapon *" = "deny";
              "swapoff *" = "deny";
              "mount *" = "deny";
              "umount *" = "deny";
            };
            task = "allow"; # Launching subagents
            skill = {
              "meet-the-agents" = "allow";
              "*" = sb "ask";
            };
            todowrite = "allow"; # Modifying todo lists
            webfetch = "allow"; # Fetching URLs
            websearch = "allow"; # Web searches
            codesearch = "allow"; # Code searches
            # Safety guards - always ask
            doom_loop = "ask"; # Repeated identical tool calls

            # External directory access - granular control
            # Triggered when accessing files outside the project directory
            external_directory = {
              # ══════════════════════════════════════════════════════════════
              # ALLOW: Safe read-only system directories
              # ══════════════════════════════════════════════════════════════
              "/tmp/*" = "allow";
              "/usr/share/*" = "allow";
              "/usr/local/share/*" = "allow";
              "/var/log/*" = "allow";

              # ALLOW: Nix store (read-only by nature)
              "/nix/store/*" = "allow";

              # ALLOW: User cache and data directories (fully qualified paths)
              "${config.xdg.cacheHome}/*" = "allow";
              "${config.xdg.dataHome}/*" = "allow";

              # ALLOW: Go module cache (read-only dependency source)
              "${config.home.homeDirectory}/go/pkg/mod/*" = "allow";

              # ALLOW: Non-sensitive config directories (fully qualified paths)
              "${config.xdg.configHome}/*" = "allow"; # General config (but SSH/GPG denied by read rules)

              # ══════════════════════════════════════════════════════════════
              # CATCHALL: Prompt for other external directories
              # ══════════════════════════════════════════════════════════════
              "*" = sb "ask";

              # ══════════════════════════════════════════════════════════════
              # DENY: Sensitive system directories (highest priority - LAST)
              # ══════════════════════════════════════════════════════════════
              "/etc/shadow" = "deny";
              "/etc/gshadow" = "deny";
              "/etc/sudoers" = "deny";
              "/etc/sudoers.d/*" = "deny";
              "/root/*" = "deny";
              "/boot/*" = "deny";

              # DENY: Sensitive user directories (fully qualified paths - defense-in-depth)
              # Match parent directory patterns that Read tool checks
              "${config.home.homeDirectory}/.ssh" = "deny";
              "${config.home.homeDirectory}/.ssh/*" = "deny";
              "${config.home.homeDirectory}/.gnupg" = "deny";
              "${config.home.homeDirectory}/.gnupg/*" = "deny";
              "${config.home.homeDirectory}/.aws" = "deny";
              "${config.home.homeDirectory}/.aws/*" = "deny";
              "${config.home.homeDirectory}/.azure" = "deny";
              "${config.home.homeDirectory}/.azure/*" = "deny";
              "${config.xdg.configHome}/gcloud" = "deny";
              "${config.xdg.configHome}/gcloud/*" = "deny";
              "${config.home.homeDirectory}/.docker" = "deny";
              "${config.home.homeDirectory}/.docker/*" = "deny";
              "${config.home.homeDirectory}/.kube" = "deny";
              "${config.home.homeDirectory}/.kube/*" = "deny";
              "${config.xdg.dataHome}/kube/" = "deny";
              "${config.xdg.dataHome}/kube/*" = "deny";
              "${config.xdg.configHome}/gh" = "deny";
              "${config.xdg.configHome}/gh/*" = "deny";
              "${config.home.homeDirectory}/.git-credentials" = "deny";
              "${config.home.homeDirectory}/.netrc" = "deny";
            };
          };
        };
      };
    };
  };
}
