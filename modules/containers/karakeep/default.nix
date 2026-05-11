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
  #  https://github.com/karakeep-app/karakeep/releases
  karakeepVersion = "0.32.0";
  karakeepImage = "ghcr.io/karakeep-app/karakeep:${karakeepVersion}";
  # Find new versions for the following two at:
  #  https://github.com/karakeep-app/karakeep/blob/main/docker/docker-compose.yml
  chromeImage = "gcr.io/zenika-hub/alpine-chrome:124";
  # https://www.meilisearch.com/docs/resources/migration/updating
  # This requires more work to update: create snapshot before updating, update, stop systemd
  #  service, run container with 'meilisearch --experimental-dumpless-upgrade', start systemd
  #  service.
  meilisearchImage = "getmeili/meilisearch:v1.41.0";

  karakeepDataDir = "${vars.containers.dataDir}/karakeep/data";
  meilisearchDataDir = "${vars.containers.dataDir}/karakeep/meilisearch-data";

  cookiesFile = funcs.relativeToAbsoluteConfigPath ./cookies.json;
in
{
  options.opts.containers.karakeep = {
    enable = lib.mkEnableOption "karakeep";
    autoStart = lib.mkEnableOption "karakeep auto-start";
  };

  config = lib.mkIf config.opts.containers.karakeep.enable {
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/karakeep 2770 ${vars.username} ${localVars.karakeep.mainGroup} - -"
      "d ${karakeepDataDir} 2770 ${vars.username} ${localVars.karakeep.mainGroup} - -"
      "Z ${karakeepDataDir}/* 770 ${vars.username} ${localVars.karakeep.mainGroup} - -"
      "d ${meilisearchDataDir} 2770 ${vars.username} ${localVars.karakeep-meilisearch.mainGroup} - -"
      "Z ${meilisearchDataDir}/* 770 ${vars.username} ${localVars.karakeep-meilisearch.mainGroup} - -"
      "Z ${cookiesFile}/* 770 ${vars.username} ${localVars.karakeep.mainGroup} - -"
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
            group = localVars.karakeep-meilisearch.mainGroup;
          }
          // value
        )
        {
          karakeep-dotenv = {
            sopsFile = ./.env;
            format = "dotenv";
          };
        };
    hm = {
      virtualisation.quadlet = {
        containers = {
          karakeep = funcs.containers.mkConfig "root" localVars.karakeep {
            inherit (config.opts.containers.karakeep) autoStart;
            containerConfig = {
              image = karakeepImage;
              environments = {
                TZ = "Europe/Lisbon";
                DATA_DIR = "/data";
                BROWSER_COOKIE_PATH = "/cookies.json";
                KARAKEEP_VERSION = karakeepVersion;
                NEXTAUTH_URL = "https://bookmarks.orangepebble.net";
                MEILI_ADDR = "http://karakeep-meilisearch:7700";
                BROWSER_WEB_URL = "http://karakeep-chrome:9222";
                DISABLE_PASSWORD_AUTH = "true";
                OAUTH_AUTO_REDIRECT = "true";
                OAUTH_WELLKNOWN_URL = "https://auth.orangepebble.net/.well-known/openid-configuration";
                OAUTH_CLIENT_ID = "karakeep";
                OAUTH_PROVIDER_NAME = "Authelia";

                MAX_ASSET_SIZE_MB = "200";
                # Leave the full page to the archival.
                CRAWLER_FULL_PAGE_SCREENSHOT = "false";
                CRAWLER_SCREENSHOT_TIMEOUT_SEC = "30";
                # Handle archival through the 'Rule Engine' so I have more control.
                CRAWLER_FULL_PAGE_ARCHIVE = "false";
                CRAWLER_VIDEO_DOWNLOAD = "true";
                # Karakeep can only download 1 file that contains video+audio which in many cases
                #  isn't the best under the max size.
                # When I tried to force it to download video and audio separately then merging
                #  using `CRAWLER_YTDLP_ARGS=bestaudio[filesize<500M]+bestvideo[filesize<500M]/best[filesize<500M]`
                #  and `CRAWLER_VIDEO_DOWNLOAD_MAX_SIZE=-1` it saved just the audio file.
                CRAWLER_VIDEO_DOWNLOAD_MAX_SIZE = "500";
                CRAWLER_PARSER_MEM_LIMIT_MB = "4096";
                # Set CRAWLER_YTDLP_ARGS on `.env` because it uses a weird format.
              };
              environmentFiles = [
                config.secrets.karakeep-dotenv.path
              ];
              volumes = [
                "${karakeepDataDir}:/data"
                "${cookiesFile}:/cookies.json"
              ];
              networks = [ "karakeep" ];
            };
          };
          karakeep-chrome = funcs.containers.mkConfig "chrome" localVars.karakeep-chrome {
            inherit (config.opts.containers.karakeep) autoStart;
            containerConfig = {
              image = chromeImage;
              exec = [
                "--no-sandbox"
                "--disable-gpu"
                "--disable-dev-shm-usage"
                "--remote-debugging-address=0.0.0.0"
                "--remote-debugging-port=9222"
                "--hide-scrollbars"
              ];
              environments = {
                TZ = "Europe/Lisbon";
              };
              networks = [ "karakeep" ];
            };
          };
          karakeep-meilisearch = funcs.containers.mkConfig "root" localVars.karakeep-meilisearch {
            inherit (config.opts.containers.karakeep) autoStart;
            containerConfig = {
              image = meilisearchImage;
              environments = {
                TZ = "Europe/Lisbon";
                MEILI_NO_ANALYTICS = "true";
              };
              environmentFiles = [
                config.secrets.karakeep-dotenv.path
              ];
              volumes = [
                "${meilisearchDataDir}:/meili_data"
              ];
              networks = [ "karakeep" ];
            };
          };
        };
        networks.karakeep = { };
      };
    };
  };
}
