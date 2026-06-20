# https://github.com/lldap/lldap/tree/main/example_configs/podman-quadlets
{
  vars,
  funcs,
  config,
  lib,
  ...
}:
let
  localVars = vars.containers.containers;
  # Find new versions at:
  #  https://github.com/lldap/lldap/pkgs/container/lldap/versions?filters[version_type]=tagged
  lldapImage = "ghcr.io/lldap/lldap:2026-05-26-alpine-rootless";
  # This is just the latest PostgreSQL version.
  postgresImage = "docker.io/postgres:18.1";
  bootstrapDir = funcs.relativeToAbsoluteConfigPath ./bootstrap;
  postgresDataDir = "${vars.containers.dataDir}/lldap/postgres-data";
in
{
  options.opts.containers.lldap = {
    enable = lib.mkEnableOption "lldap";
    autoStart = lib.mkEnableOption "lldap auto-start";
  };

  config = lib.mkIf config.opts.containers.lldap.enable {
    systemd.tmpfiles.rules = [
      "d ${bootstrapDir} 2770 ${vars.username} ${localVars.lldap.mainGroup} - -"
      "Z ${bootstrapDir}/* 770 ${vars.username} ${localVars.lldap.mainGroup} - -"
      "d ${bootstrapDir}/user-configs 770 ${vars.username} ${localVars.lldap.mainGroup} - -"
      "L+ ${bootstrapDir}/user-configs/authelia.json - - - - ${config.secrets.lldap-authelia-user.path}"
      "d ${vars.containers.dataDir}/lldap 2770 ${vars.username} ${localVars.lldap.mainGroup} - -"
      "d ${postgresDataDir} 2770 ${vars.username} ${localVars.lldap-postgres.mainGroup} - -"
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
            group = localVars.lldap.mainGroup;
          }
          // value
        )
        {
          # Random string:
          # `LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\\]^_{|}~' </dev/urandom | head -c 32`
          # Automatically encrypt string with sops:
          # `sops --input-type binary -e <(LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\\]^_{|}~' </dev/urandom | head -c 32) > <file path>`
          lldap-jwt-secret.sopsFile = ./secrets/jwt-secret;
          lldap-key-seed.sopsFile = ./secrets/key-seed;
          lldap-ldap-user-pass.sopsFile = ./secrets/ldap-user-pass;
          lldap-authelia-user = {
            sopsFile = ./secrets/authelia-user.json;
            format = "json";
          };
        };
    hm = {
      virtualisation.quadlet = {
        networks = {
          lldap = { };
          lldap-authelia = { };
        };
        containers = {
          authelia.containerConfig.networks = [ "lldap-authelia" ];
          lldap = funcs.containers.mkConfig "1000" localVars.lldap {
            autoStart = config.opts.containers.lldap.autoStart;
            unitConfig.Requires = "lldap-postgres.container";
            containerConfig =
              let
                secretValues =
                  builtins.zipAttrsWith
                    (name: values: if name == "environments" then lib.mergeAttrsList values else values)
                    (
                      builtins.map
                        (x: {
                          environments.${x.name} = x.value;
                          # https://docs.podman.io/en/latest/markdown/podman-run.1.html#secret-secret-opt-opt
                          # Not using the 'secrets' option because that would require extra configuration.
                          volumes = "${x.value}:${x.value}";
                        })
                        (
                          lib.attrsToList {
                            LLDAP_JWT_SECRET_FILE = config.secrets.lldap-jwt-secret.path;
                            LLDAP_KEY_SEED_FILE = config.secrets.lldap-key-seed.path;
                            LLDAP_LDAP_USER_PASS_FILe = config.secrets.lldap-ldap-user-pass.path;
                          }
                        )
                    );
              in
              {
                image = lldapImage;
                environments = {
                  UID = "1000";
                  GID = "1000";
                  LLDAP_LDAP_BASE_DN = "dc=orangepebble,dc=net";
                  LLDAP_DATABASE_URL = "postgres://lldapuser:lldappass@lldap-db/lldap";
                  LLDAP_LDAP_USER_EMAIL = "orangepebbleauth+lldap@gmail.com";

                  # For bootstrapping (running a script to declaratively setup admin, users, and groups):
                  # `podman exec -ti lldap bash /bootstrap/bootstrap.sh`
                  # Should be removed after bootstrapping for less attack vectors.
                  # LLDAP_ADMIN_PASSWORD_FILE = config.secrets.lldap-ldap-user-pass.path;
                }
                // secretValues.environments;
                volumes = [
                  # For bootstrapping (running a script to declaratively setup admin, users, and groups):
                  # `podman exec -ti lldap bash /bootstrap/bootstrap.sh`
                  # Should be removed after bootstrapping for less attack vectors.
                  # "${bootstrapDir}:/bootstrap:ro"
                  # "${config.secrets.lldap-authelia-user.path}:${config.secrets.lldap-authelia-user.path}"
                ]
                ++ secretValues.volumes;
                networks = [
                  "lldap"
                  "lldap-authelia"
                ];
              };
          };
          lldap-postgres = funcs.containers.mkConfig "postgres" localVars.lldap-postgres {
            containerConfig = {
              image = postgresImage;
              environments = {
                POSTGRES_DB = "lldap";
                POSTGRES_USER = "lldapuser";
                POSTGRES_PASSWORD = "lldappass";
                POSTGRES_INITDB_ARGS = "--data-checksums";
                DB_STORAGE_TYPE = "HDD";
              };
              volumes = [
                "${postgresDataDir}:/var/lib/postgresql"
              ];
              shmSize = "128mb";
              networkAliases = [ "lldap-db" ];
              networks = [ "lldap" ];
            };
          };
        };
      };
    };
  };
}
