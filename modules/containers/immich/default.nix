# https://github.com/immich-app/immich
{
  vars,
  funcs,
  lib,
  config,
  ...
}:
let
  localVars = vars.containers.containers;
  # Find new versions at:
  #  https://github.com/immich-app/immich/releases
  immichImage = "ghcr.io/immich-app/immich-server:v2.7.5";
  machineLearningImage = "ghcr.io/immich-app/immich-machine-learning:v2.7.5";
  # Obtained versions from the release 'docker-compose.yml'.
  redisImage = "ghcr.io/valkey-io/valkey:9.0.1";
  databaseImage = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";

  immichUploadDir = "${vars.containers.publicDir}/gallery";
  databaseDataDir = "${vars.containers.dataDir}/immich/database/data";
  machineLearningCacheDir = "${vars.containers.dataDir}/immich/machine-learning/cache";

  env = {
    TZ = "Europe/Lisbon";
    DB_USERNAME = "postgres";
    DB_DATABASE_NAME = "immich";
  };

  databaseUID = "999"; # The 'postgres' user.
  databaseHostUID = toString (
    (lib.toInt databaseUID)
    + vars.containers.uidGidCount * localVars.immich-database.i
    + (builtins.elemAt config.users.users.${vars.username}.subUidRanges 0).startUid
  );
in
{
  options.opts.containers.immich = {
    enable = lib.mkEnableOption "Immich";
    autoStart = lib.mkEnableOption "Immich auto-start";
  };

  config = lib.mkIf config.opts.containers.immich.enable {
    systemd.tmpfiles.rules = [
      "d ${immichUploadDir} 2770 ${vars.username} public - -"
      "Z ${immichUploadDir}/* 770 ${vars.username} public - -"

      "d ${vars.containers.dataDir}/immich 2770 ${vars.username} ${localVars.immich.mainGroup} - -"

      "d ${vars.containers.dataDir}/immich/database 2770 ${vars.username} ${localVars.immich-database.mainGroup} - -"
      "d ${databaseDataDir} 2770 ${databaseHostUID} ${localVars.immich-database.mainGroup} - -"
      "Z ${databaseDataDir}/* 770 ${databaseHostUID} ${localVars.immich-database.mainGroup} - -"

      "d ${vars.containers.dataDir}/immich/machine-learning 2770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"
      "d ${machineLearningCacheDir} 2770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"
      "Z ${machineLearningCacheDir}/* 770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"
    ];
    secrets =
      builtins.mapAttrs
        (
          _: value:
          {
            format = "binary";
            # Entire file.
            key = "";
            # Only the user and group can read and nothing else.
            mode = "0440";
            owner = vars.username;
            group = localVars.immich.mainGroup;
          }
          // value
        )
        {
          immich-postgres-password = {
            sopsFile = ./secrets/postgres-password.env;
            format = "dotenv";
          };
          # It is a bit annoying to have to always use sops to edit this file but
          #  its the easiest way to encrypt the secrets within.
          immich-config-file = {
            sopsFile = ./secrets/immich.json;
            format = "json";
          };
        };
    hm = {
      virtualisation.quadlet = {
        # https://github.com/linux-universe/immich-podman-quadlets
        containers = {
          immich = funcs.containers.mkConfig "node" localVars.immich {
            autoStart = config.opts.containers.immich.autoStart;
            # This makes it so that the other containers can have autoStart as
            #  false, but even so this container will start before the ones
            #  it depends on and fail at least once per startup.
            unitConfig = {
              Requires = "immich-redis.container immich-database.container";
              Wants = "immich-machine-learning.container";
            };
            containerConfig = {
              image = immichImage;
              # publishPorts = ["2283:2283"];
              environments = {
                IMMICH_CONFIG_FILE = config.secrets.immich-config-file.path;
              }
              // env;
              environmentFiles = [ config.secrets.immich-postgres-password.path ];
              volumes = [
                "${immichUploadDir}:/data"
                "/etc/localtime:/etc/localtime:ro"
                "${config.secrets.immich-config-file.path}:${config.secrets.immich-config-file.path}"
              ];
              networks = [ "immich" ];
            };
          };
          immich-machine-learning = funcs.containers.mkConfig "root" localVars.immich-machine-learning {
            containerConfig = {
              image = machineLearningImage;
              volumes = [
                "${machineLearningCacheDir}:/cache"
              ];
              networks = [ "immich" ];
              networkAliases = [ "immich-machine-learning" ];
              dropCapabilities = vars.containers.rootCapabilities;
            };
          };
          immich-redis = funcs.containers.mkConfig "valkey" localVars.immich-redis {
            containerConfig = {
              image = redisImage;
              networks = [ "immich" ];
              networkAliases = [ "redis" ];
            };
          };
          immich-database = funcs.containers.mkConfig databaseUID localVars.immich-database {
            containerConfig = {
              image = databaseImage;
              environments = {
                POSTGRES_USER = env.DB_USERNAME;
                POSTGRES_DB = env.DB_DATABASE_NAME;
                POSTGRES_INITDB_ARGS = "--data-checksums";
                DB_STORAGE_TYPE = "HDD";
              };
              environmentFiles = [ config.secrets.immich-postgres-password.path ];
              volumes = [
                "${databaseDataDir}:/var/lib/postgresql/data"
              ];
              shmSize = "128mb";
              networks = [ "immich" ];
              networkAliases = [ "database" ];
            };
          };
        };
        networks.immich = { };
      };
    };
  };
}
