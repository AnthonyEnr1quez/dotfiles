# Firefox profile migration for macOS 27

macOS 27 blocks Nix-wrapped Firefox from accessing Mozilla's profile directory.
Migrate to `~/Library/Application Support/org.nixos.firefox` before upgrading.
You can use the new directory on older macOS versions too.

See [nixpkgs issue #535123](https://github.com/NixOS/nixpkgs/issues/535123).

## Migrate

1. Pull the latest dotfiles, including commit `6cf9887`:

   ```fish
   cd ~/Projects/nix/dotfiles
   git pull
   ```

2. Quit Firefox completely. If you already upgraded to macOS 27, grant your
   terminal app **Full Disk Access** in System Settings → Privacy & Security,
   then quit and reopen the terminal app.

3. Paste the block for your shell as your normal user. These commands use
   `nix shell` to select GNU `cp`; macOS's `/bin/cp` rejects the long options.

   **Fish:**

   ```fish
   set source_dir "$HOME/Library/Application Support/Firefox"
   set destination_dir "$HOME/Library/Application Support/org.nixos.firefox"

   if test -e "$destination_dir"
       echo "Destination already exists; stop and check it before copying."
   else if not test -d "$source_dir"
       echo "Source directory is missing; check your Firefox profile location."
   else
       mkdir "$destination_dir"; and \
        nix shell nixpkgs#coreutils --command cp --recursive \
           --preserve=mode,timestamps,links \
           --no-preserve=ownership,xattr,context \
           "$source_dir/." "$destination_dir/"; and \
        /usr/bin/find "$destination_dir" -name .parentlock -delete
   end
   ```

   **Zsh:**

   ```zsh
   source_dir="$HOME/Library/Application Support/Firefox"
   destination_dir="$HOME/Library/Application Support/org.nixos.firefox"

   if test -e "$destination_dir"; then
       echo "Destination already exists; stop and check it before copying."
   elif ! test -d "$source_dir"; then
       echo "Source directory is missing; check your Firefox profile location."
   else
       mkdir "$destination_dir" &&
        nix shell nixpkgs#coreutils --command cp --recursive \
           --preserve=mode,timestamps,links \
           --no-preserve=ownership,xattr,context \
           "$source_dir/." "$destination_dir/" &&
        /usr/bin/find "$destination_dir" -name .parentlock -delete
   fi
   ```

   The copy preserves your original directory and omits extended attributes
   that can associate copied files with Mozilla's protected directory.
   If you see an error or an existing-destination message, stop before rebuilding.
   A failed copy can leave a partial destination; check it before retrying.

   If you got `cp: illegal option -- -`, the command used macOS's `cp` and
   stopped before copying. With Firefox still closed, run:

   ```sh
   rmdir "$HOME/Library/Application Support/org.nixos.firefox"
   ```

   Then retry the block above. If `rmdir` reports that the directory is not
   empty, inspect its contents before moving it aside or removing it.

4. Apply the configuration from the dotfiles repository:

   ```fish
   cd ~/Projects/nix/dotfiles
   sudo darwin-rebuild switch --flake .
   ```

## Verify

Open Firefox and check your tabs, bookmarks, logins, and extensions. In
`about:support`, confirm that **Profile Directory** points into:

```text
~/Library/Application Support/org.nixos.firefox/Profiles/default
```

Home Manager may print “does not link into a Home Manager generation. Skipping
delete” for extension files under the old `Firefox` directory. It leaves those
files in place; those notices do not indicate a failed migration.

After checking Firefox, revoke your terminal's Full Disk Access if you granted
it for this migration. Keep the old `Firefox` directory as a backup for a few
days, then delete it once you are satisfied. Keep `org.nixos.firefox` as your
active data directory.

You can now upgrade macOS if you have not done so yet.
