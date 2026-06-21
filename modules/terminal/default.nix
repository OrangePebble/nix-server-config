{
  pkgs,
  vars,
  funcs,
  inputs,
  ...
}:
{
  imports = [
    ./neovim

    # Tool to locate the nixpkgs package providing a certain file. Used by comma.
    # Unlike regular nix-index, this one includes an automatically updated database, and so I don't
    #  need to manually update it every once in a while.
    inputs.nix-index-database.darwinModules.nix-index
  ];

  users.defaultUserShell = pkgs.zsh;
  environment = {
    shells = with pkgs; [
      zsh
      bash
    ];
    shellAliases = {
      lg = "lazygit";

      # Undoes a commit but keeps the changes.
      gitr = "git reset --soft HEAD~1";

      # I've been typing this so much working with the containers that I want
      #  an easier way.
      sysc = "systemctl";
      syscu = "systemctl --user";

      # Runs a script that rebuild switches this config.
      nixs = toString (funcs.mkMutableConfigSymlink ./nixs.sh);
      nixb = "sudo nixos-rebuild build --flake ${vars.configDirectory}";
      nixl = "nixos-rebuild list-generations";
      nixu = "nix flake update --flake ${vars.configDirectory}";
      nixd = "nix develop -c $SHELL";
      nixp = "nix-shell --run $SHELL -p";

      # Runs nix repl initialized with values from this flake for easier testing and debugging.
      nixr = "nix repl --file ${pkgs.writeText "replinit.nix" ''
        let
          self = builtins.getFlake "config";
        in rec {
          inherit self;
          inherit (self) inputs lib;
          inherit (self.nixosConfigurations) ${vars.hostname};
          inherit (self.nixosConfigurations ${vars.hostname}) pkgs;
          inherit (self.nixosConfigurations.${vars.hostname}._module.specialArgs) vars;
          inherit (self.nixosConfigurations.${vars.hostname}._module.args) funcs;
        }
      ''}";
    };
  };
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      # Used by my prompt.
      ohMyZsh.enable = true;
      promptInit = ''
        ZSH_NOTIFY_ICON=${pkgs.foot}/share/icons/hicolor/scalable/apps/foot.svg
        FREEDESKTOP_SOUNDS_DIR=${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop
        source "${funcs.mkMutableConfigSymlink ./prompt.zsh}"
      '';
      interactiveShellInit = ''
        ZSH_VI_MODE_PLUGIN_FILE="${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
        source "${funcs.mkMutableConfigSymlink ./.zshrc}"
      '';
    };
    bash.enable = true;
    git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
        user.name = "OrangePebble";
        user.email = "git@orangepebble.net";

        credential.helper = "store";
        core.pager = "delta";
        interactive.diffFilter = "delta --color-only";
        delta = {
          navigate = "true"; # use n and N to move between diff sections
          dark = "true";
          line-numbers = "true";
          hyperlinks = "true";
        };
        merge.conflictStyle = "zdiff3";
      };
      # Git extension for versioning large files (Git Large File Storage).
      lfs.enable = true;
    };

    # CLI tool to run programs without installing them on Nix. Functionally an easier to use nix-shell. Requires nix-index.
    nix-index-database.comma.enable = true;
    nix-index.enable = true;
  };

  hm.programs = {
    gh.enable = true;

    # Throws an error when not set with home manager.
    zoxide.enable = true;
    zsh = {
      # Required for zoxide to set the 'z' and 'zi' commands when set with home manager.
      enable = true;
      # Removes rebuild warning.
      dotDir = "${vars.homeDirectory}/.config/zsh";
    };
  };

  environment.systemPackages = with pkgs; [
    # Tool to remove large files from git history. Call with "bfg".
    bfg-repo-cleaner

    # TUI for git.
    lazygit

    # App to give quick examples of how to use most commands.
    tldr

    # Nix formatter.
    nixfmt
    # Formatter multiplexer
    treefmt
    # Nix package version diff tool.
    nvd

    # find replacement, used to update fetchgit references together with update-nix-fetchgit in nixr.
    fd
    update-nix-fetchgit

    # Library with a bunch of terminal inputs and outputs.
    gum

    # Tool to see file changes in real time.
    fswatch

    # Syntax highlighting pager.
    delta

    # 'cat' replacement with syntax highlighting.
    bat

    # Calculator used by my zsh prompt to calculate run times.
    bc

    # Adds the `git credential-oauth` command to authenticate to Forejo (and others) using OAuth.
    git-credential-oauth

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];
}
