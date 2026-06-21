{
  vars,
  funcs,
  config,
  lib,
  ...
}:
let
  localVars = vars.containers.containers.syncyomi;

  # Find new versions at:
  #  https://github.com/syncyomi/syncyomi/releases
  syncyomiImage = "ghcr.io/syncyomi/syncyomi:v1.1.8";

  syncyomiDataDir = "${vars.containers.dataDir}/syncyomi/data";

  containerUID = "0";
  hostUID = toString (
    (lib.toInt containerUID)
    + vars.containers.uidGidCount * localVars.i
    + (builtins.elemAt config.users.users.${vars.username}.subUidRanges 0).startUid
  );
in
{
  options.opts.containers.syncyomi = {
    enable = lib.mkEnableOption "SyncYomi";
    autoStart = lib.mkEnableOption "SyncYomi auto-start";
  };

  config = lib.mkIf config.opts.containers.syncyomi.enable {
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/syncyomi 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${syncyomiDataDir} 2770 ${hostUID} ${localVars.mainGroup} - -"
    ];
    hm = {
      virtualisation.quadlet = {
        containers = {
          syncyomi = funcs.containers.mkConfig containerUID localVars {
            autoStart = config.opts.containers.syncyomi.autoStart;
            containerConfig = {
              image = syncyomiImage;
              environments = {
                TZ = "Europe/Lisbon";
              };
              volumes = [
                "${syncyomiDataDir}:/config"
              ];
            };
          };
        };
      };
    };
  };
}
