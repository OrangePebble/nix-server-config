{
  pkgs,
  funcs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # Dependencies (the comments are what made me install them, not all they might be used for)
    wl-clipboard # Clipboard provider for Wayland.
    xclip # Clipboard provider for X11/RDP.
    ripgrep # Search tool.
    fzf # Fuzzy finder.
    luarocks # Lua package manager used by some plugins.
    lua51Packages.lua # Version lazy.nvim (with :checkhealth) says it needs.
    tree-sitter
    gcc # Required to compile treesitter parsers.
    gnumake # Required for LuaSnip.
    unzip # Used to install packages with Mason.
    cargo # Used to install the nil Nix LSP.
    nodejs_25 # For the bash LSP.
    python315 # For the python linter and formatter.

    # LSPs, DAPs, Linters and Formatters not installed with Mason.
    statix
    # quickshell (.qml)
    # qmllint requires more configuration that I don't know how to do.
    kdePackages.qtdeclarative
    clang-tools # C/C++ LSP/linter/formatter.
    cmake-language-server
    gersemi # cmake formatter.
    cmake-lint
  ];
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };
  hm = {
    home.file.".config/nvim".source = funcs.mkMutableConfigSymlink ./config;
  };
  environment.shellAliases = {
    vi = "nvim";
    vim = "nvim";
    vi2 = "NVIM_APPNAME=nvim2 nvvi";
    vim2 = "NVIM_APPNAME=nvim2 nvim";
    nvim2 = "NVIM_APPNAME=nvim2 nvim";
  };
}
