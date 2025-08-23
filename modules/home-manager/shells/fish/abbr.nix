{ config, pkgs, lib, ... }: {
  programs.fish.shellAbbrs = {
    gcm = "git commit -m";
    gcam = "git add . && git commit -m";
    gf = "git fetch --all";
    gfo = "git fetch origin && git checkout main && git rebase origin/main";
    gfu = "git fetch upstream && git checkout main && git rebase upstream/main";
    gitpurge = "git fetch --all -p; git branch -vv | grep \": gone]\" | awk \"{ print \$1 }\" | xargs -n 1 git branch -D";
    gp = "git push";
    gs = "git status -sb";

    mcc = "mvn clean compile";
    mci = "mvn clean install";
    mcp = "mvn clean package -DskipTests";
    mcs = "mvn clean site";
    mec = "mvn eclipse:clean";
    mee = "mvn eclipse:eclipse -DdownloadSources=true -DdownloadJavadocs=true -Declipse.useProjectReferences=false -U";
    mfr = "mvn release:prepare -DdryRun=true";
    mr = "mvn release:prepare";
    mrb = "mvn clean eclipse:clean; mvn install -DskipTests; mvn eclipse:eclipse";
    mqi = "mvn clean install -DskipTests";
  };
}
