{
  vars,
  funcs,
  config,
  lib,
  ...
}:
let
  localVars = vars.containers.containers.navidrome;

  # Find new versions at:
  #  https://github.com/navidrome/navidrome/releases
  navidromeImage = "ghcr.io/navidrome/navidrome:0.62.0";

  navidromeDataDir = "${vars.containers.dataDir}/navidrome/data";
  navidromeBackupDir = "${vars.containers.dataDir}/navidrome/backup";
  musicDir = "${vars.containers.publicDir}/music";
in
{
  options.opts.containers.navidrome = {
    enable = lib.mkEnableOption "Navidrome";
    autoStart = lib.mkEnableOption "Navidrome auto-start";
  };

  config = lib.mkIf config.opts.containers.navidrome.enable {
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/navidrome 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${navidromeDataDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${navidromeBackupDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${musicDir} 2770 ${vars.username} public - -"
      "d ${musicDir}/default 2770 ${vars.username} public - -"
      "Z ${musicDir}/default/* 774 ${vars.username} public - -"
      "d ${musicDir}/personal 2770 ${vars.username} public - -"
      "Z ${musicDir}/personal/* 774 ${vars.username} public - -"
    ];
    hm = {
      virtualisation.quadlet = {
        containers = {
          navidrome = funcs.containers.mkConfig "1000" localVars {
            autoStart = config.opts.containers.navidrome.autoStart;
            containerConfig = {
              image = navidromeImage;
              environments = {
                ND_LOGLEVEL = "debug";
                ND_BASEURL = "https://music.orangpebble.net";
                ND_EXTAUTH_TRUSTEDSOURCES = "10.0.0.0/8";
                # Use a default subfolder for multi-library support.
                ND_MUSICFOLDER = "/music/default";
                # Backup the database.
                ND_BACKUP_PATH = "/backup";
                ND_BACKUP_SCHEDULE = "0 0 * * *"; # Every 24h
                ND_BACKUP_COUNT = "7";
                # Required for auth with Subsonic API bypassing Authelia.
                ND_ENABLEUSEREDITING = "true";
                # Sharing.
                ND_ENABLESHARING = "true";
              };
              volumes = [
                "${navidromeDataDir}:/data"
                "${navidromeBackupDir}:/backup"
                "${musicDir}:/music:ro"
              ];
            };
          };
        };
      };
    };
  };
}
