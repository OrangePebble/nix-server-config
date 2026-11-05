{
  config,
  inputs,
  lib,
  vars,
  funcs,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.default
    (lib.mkAliasOptionModule [ "hm" ] [ "home-manager" "users" vars.username ])
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
    backupFileExtension = "backup";
    overwriteBackup = false;
    extraSpecialArgs = { inherit inputs vars funcs; };
    # For modules shared by all users;
    sharedModules = [ ];
  };

  hm = {
    home = {
      username = vars.username;
      homeDirectory = config.users.users.${vars.username}.home;
      stateVersion = config.system.stateVersion;
    };

    # Nicely reload system units when changing configs.
    systemd.user.startServices = "sd-switch";

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;
  };
}
