# For functions that depend on modules like nixos and home-manager.
# For more "pure"/standard functions check ../lib
{
  config,
  lib,
  funcs,
  vars,
  ...
}:
with lib;
{
  # Using this options instead of '_module.args' directly because I can't set
  #  'funcs' im multiple places at once without an error otherwise (it wants
  #  arguments to be set only once. NixOS options merge all the different
  #  values set before acting on them.
  options.opts.funcs = mkOption {
    default = { };
    type = with types; attrsOf anything;
  };

  imports = lib.attrValues (lib.modulesIn ./.);

  config = {
    # https://mynixos.com/nixpkgs/option/_module.args
    # Additional arguments passed to each module.
    # Default arguments like 'lib' and 'config' cannot be modified.
    _module.args.funcs = config.opts.funcs;

    opts.funcs = {
      mkOutOfStoreSymlink = path: config.hm.lib.file.mkOutOfStoreSymlink path;

      # When this is called 'path' is inside the nix store, so we need to replace
      #  the nix store path with the path to our config.
      # To do this, we need to replace the store prefix, and because this file is 2
      #  folders deep in the config `(toString ./../..)' is equivalent to the store
      #  directory.
      relativeToAbsoluteConfigPath =
        path:
        (
          "${config.users.users.${vars.username}.home}/nix-server-config"
          + removePrefix (toString ./../..) (toString path)
        );

      # Creates symlinks to these config files that can be changed without rebuilding.
      mkMutableConfigSymlink = path: funcs.mkOutOfStoreSymlink (funcs.relativeToAbsoluteConfigPath path);
    };
  };
}
