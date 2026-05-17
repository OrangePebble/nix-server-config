# Git service.
# Run `podman exec -it forgejo forgejo doctor check` to check for problems.
# To add mirrors to my GitHub:
#  - Create new migration in the top right.
#  - In the repo settings, add a new pushed repository.
#    - The authorization username is the GitHub username and the password is a personal access token.
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
  #  https://codeberg.org/forgejo/-/packages/container/forgejo/versions
  forgejoImage = "codeberg.org/forgejo/forgejo:15.0.2-rootless";
  # This is just the latest PostgreSQL version.
  postgresImage = "docker.io/postgres:18.1";

  forgejoDataDir = "${vars.containers.dataDir}/forgejo/data";
  postgresDataDir = "${vars.containers.dataDir}/forgejo/postgres-data";
in
{
  options.opts.containers.forgejo = {
    enable = lib.mkEnableOption "forgejo";
    autoStart = lib.mkEnableOption "forgejo auto-start";
  };

  config = lib.mkIf config.opts.containers.forgejo.enable {
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/forgejo 2770 ${vars.username} ${localVars.forgejo.mainGroup} - -"
      "d ${forgejoDataDir} 2770 ${vars.username} ${localVars.forgejo.mainGroup} - -"
      "Z ${forgejoDataDir}/* 770 ${vars.username} ${localVars.forgejo.mainGroup} - -"
      "d ${postgresDataDir} 2770 ${vars.username} ${localVars.forgejo-postgres.mainGroup} - -"
      "Z ${postgresDataDir}/* 770 ${vars.username} ${localVars.forgejo-postgres.mainGroup} - -"
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
            group = localVars.forgejo.mainGroup;
          }
          // value
        )
        {
          # Random string:
          # `LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\\]^_{|}~' </dev/urandom | head -c 32`
          forgejo-postgres-password = {
            sopsFile = ./secrets/postgres-password.env;
            format = "dotenv";
          };
          forgejo-postgres-postgres-password = {
            sopsFile = ./secrets/postgres-password.env;
            format = "dotenv";
            group = localVars.forgejo-postgres.mainGroup;
          };
        };
    hm = {
      virtualisation.quadlet = {
        containers = {
          forgejo = funcs.containers.mkConfig "1000" localVars.forgejo {
            inherit (config.opts.containers.forgejo) autoStart;
            unitConfig.Requires = "forgejo-postgres.container";
            containerConfig = {
              image = forgejoImage;
              environmentFiles = [
                config.secrets.forgejo-postgres-password.path
              ];
              environments = {
                USER_UID = "1000";
                USER_GID = funcs.containers.getContainerGid localVars.forgejo.mainGroup;
                FORGEJO____APP_SLOGAN = "";
                FORGEJO__database__DB_TYPE = "postgres";
                FORGEJO__database__HOST = "forgejo-postgres:5432";
                FORGEJO__database__NAME = "forgejo";
                FORGEJO__database__USER = "forgejo";

                # WARN: There are a couple of manual steps to configure Authelia.
                # Get into the container with 'podman exec -it forgejo sh'.
                # Run `forgejo migrate`.
                # The insecure secret for the next command can be found on `./secrets/authelia-secret`.
                # Run `forgejo admin auth add-oauth --provider=openidConnect --name=authelia --key=forgejo --secret=<insecure secret> --auto-discover-url=https://auth.orangepebble.net/.well-known/openid-configuration --scopes='openid email profile groups forgejo' --attribute-ssh-public-key=sshpubkey`.
                FORGEJO__openid__ENABLE_OPENID_SIGNIN = "false";
                FORGEJO__openid__ENABLE_OPENID_SIGNUP = "true";
                FORGEJO__openid__WHITELISTED_URIS = "auth.orangepebble.net";
                FORGEJO__service__DISABLE_REGISTRATION = "false";
                FORGEJO__service__ALLOW_ONLY_EXTERNAL_REGISTRATION = "true";
                FORGEJO__service__SHOW_REGISTRATION_BUTTON = "false";

                # https://forgejo.org/docs/latest/admin/setup/recommendations
                FORGEJO__cache__ADAPTER = "twoqueue";
                FORGEJO__cache__HOST = ''{"size":100, "recent_ratio":0.25, "ghost_ratio":0.5}'';
                FORGEJO__security__LOGIN_REMEMBER_DAYS = "365";
              };
              volumes = [
                "${forgejoDataDir}:/var/lib/gitea"
                "/etc/localtime:/etc/localtime:ro"
              ];
              networks = [
                "forgejo"
              ];
            };
          };
          forgejo-postgres = funcs.containers.mkConfig "postgres" localVars.forgejo-postgres {
            containerConfig = {
              image = postgresImage;
              environmentFiles = [
                config.secrets.forgejo-postgres-postgres-password.path
              ];
              environments = {
                POSTGRES_DB = "forgejo";
                POSTGRES_USER = "forgejo";
              };
              volumes = [
                "${postgresDataDir}:/var/lib/postgresql"
              ];
              networks = [ "forgejo" ];
            };
          };
        };
        networks = {
          forgejo = { };
        };
      };
    };
  };
}
