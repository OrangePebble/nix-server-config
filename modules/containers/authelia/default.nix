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
  #  https://github.com/authelia/authelia/releases
  autheliaImage = "ghcr.io/authelia/authelia:4.39.20";
  # Redis and PostgreSQL versions are not specified, latest stable is the recommendation.
  # Valkey is a Redis replacement so the same for that.
  valkeyImage = "ghcr.io/valkey-io/valkey:9.0.1";
  postgresImage = "docker.io/postgres:18.1";
  configDir = funcs.relativeToAbsoluteConfigPath ./config;
  valkeyDataDir = "${vars.containers.dataDir}/authelia/valkey-data";
  postgresDataDir = "${vars.containers.dataDir}/authelia/postgres-data";
in
{
  options.opts.containers.authelia = {
    enable = lib.mkEnableOption "Authelia";
    autoStart = lib.mkEnableOption "Authelia auto-start";
  };

  config = lib.mkIf config.opts.containers.authelia.enable {
    systemd.tmpfiles.rules = [
      "d ${configDir} 2770 ${vars.username} ${localVars.authelia.mainGroup} - -"
      "Z ${configDir}/* 770 ${vars.username} ${localVars.authelia.mainGroup} - -"
      "d ${vars.containers.dataDir}/authelia 2770 ${vars.username} ${localVars.authelia.mainGroup} - -"
      "d ${valkeyDataDir} 2770 ${vars.username} ${localVars.authelia-valkey.mainGroup} - -"
      "d ${postgresDataDir} 2770 ${vars.username} ${localVars.authelia-postgres.mainGroup} - -"
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
            group = localVars.authelia.mainGroup;
          }
          // value
        )
        {
          # https://www.authelia.com/reference/guides/generating-secure-values/#generating-a-random-alphanumeric-string
          # For a random alphanumeric string with length 128:
          # `tr -cd '[:alnum:]' < /dev/urandom | fold -w "128" | head -n 1 | tr -d '\n'`
          # To automatically encrypt:
          # `sops --input-type binary -e <(tr -cd '[:alnum:]' < /dev/urandom | fold -w "128" | head -n 1 | tr -d '\n') > <file path>`
          authelia-JWT_SECRET.sopsFile = ./secrets/JWT_SECRET;
          authelia-SESSION_SECRET.sopsFile = ./secrets/SESSION_SECRET;
          authelia-STORAGE_PASSWORD.sopsFile = ./secrets/STORAGE_PASSWORD;
          authelia-STORAGE_ENCRYPTION_KEY.sopsFile = ./secrets/STORAGE_ENCRYPTION_KEY;
          authelia-SMTP_PASSWORD.sopsFile = ./secrets/SMTP_PASSWORD;
          authelia-postgres-POSTGRES_PASSWORD = {
            sopsFile = ./secrets/STORAGE_PASSWORD.env;
            format = "dotenv";
            group = localVars.authelia-postgres.mainGroup;
          };
          authelia-ldap-password.sopsFile = ./secrets/ldap-password;
          # Obtained by running:
          #  `authelia crypto pair rsa generate`
          #  `sops -e private.pem > <file path/name>`
          authelia-oidc-jwks-key.sopsFile = ./secrets/oidc-jwks-key.pem;
        };
    hm = {
      virtualisation.quadlet = {
        containers = {
          authelia = funcs.containers.mkConfig "root" localVars.authelia {
            autoStart = config.opts.containers.authelia.autoStart;
            unitConfig.Requires = "lldap.container authelia-valkey.container authelia-postgres.container";
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
                            AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE =
                              config.secrets.authelia-JWT_SECRET.path;
                            AUTHELIA_SESSION_SECRET_FILE = config.secrets.authelia-SESSION_SECRET.path;
                            AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE = config.secrets.authelia-STORAGE_PASSWORD.path;
                            AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE = config.secrets.authelia-STORAGE_ENCRYPTION_KEY.path;
                            AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE = config.secrets.authelia-SMTP_PASSWORD.path;
                            AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = config.secrets.authelia-ldap-password.path;
                            OIDC_JWKS_KEY_FILE = config.secrets.authelia-oidc-jwks-key.path;
                          }
                        )
                    );
              in
              {
                image = autheliaImage;
                environments = {
                  # https://www.authelia.com/configuration/methods/files/#file-filters
                  # Allows for templates that use the Go template engine in the
                  #  YAML configuration file.
                  X_AUTHELIA_CONFIG_FILTERS = "template";
                }
                // secretValues.environments;
                volumes = [ "${configDir}:/config" ] ++ secretValues.volumes;
                networks = [ "authelia" ];
              };
          };
          authelia-valkey = funcs.containers.mkConfig "valkey" localVars.authelia-valkey {
            containerConfig = {
              image = valkeyImage;
              volumes = [ "${valkeyDataDir}:/data" ];
              networkAliases = [ "redis" ];
              networks = [ "authelia" ];
            };
          };
          authelia-postgres = funcs.containers.mkConfig "postgres" localVars.authelia-postgres {
            containerConfig = {
              image = postgresImage;
              environmentFiles = [
                (toString config.secrets.authelia-postgres-POSTGRES_PASSWORD.path)
              ];
              environments = {
                POSTGRES_USER = "authelia";
                POSTGRES_DB = "authelia";
                POSTGRES_INITDB_ARGS = "--data-checksums";
                DB_STORAGE_TYPE = "HDD";
              };
              volumes = [
                "${postgresDataDir}:/var/lib/postgresql"
              ];
              shmSize = "128mb";
              networkAliases = [ "postgres" ];
              networks = [ "authelia" ];
            };
          };
        };
        networks.authelia = { };
      };
    };
  };
}
