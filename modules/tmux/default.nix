{ pkgs, funcs, ... }:
{
  programs = {
    tmux.enable = true;
  };

  hm = {
    home.file = {
      ".config/tmux/tmux.conf".source = funcs.mkMutableConfigSymlink ./tmux.conf;
      ".config/tmux/plugins/tpm".source = funcs.mkOutOfStoreSymlink (
        pkgs.fetchFromGitHub {
          owner = "tmux-plugins";
          repo = "tpm";
          rev = "master";
          hash = "sha256-oRKUZNyJYQXlkeQfbEYiltUEBpvdwn2SoEBWHVUNmrA=";
        }
      );
      ".config/tmux/plugins/tmux-which-key/config.yaml".source =
        funcs.mkMutableConfigSymlink ./which-key.yaml;
      ".config/tmux/scripts".source = funcs.mkMutableConfigSymlink ./scripts;
    };
  };
}
