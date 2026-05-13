# Customizable AI web interface, works as an alternative to Perplexity.
# Get models on:
#  https://ollama.com/search
#  https://huggingface.co
# The non-embedding model requires tools support.
# Make sure to choose models with parameters small enough for the GPU.
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
  #  https://github.com/open-webui/open-webui/releases
  # Not using the latest version at the time of writing because web search was broken:
  #  https://github.com/open-webui/open-webui/issues/24560
  openwebuiImage = "ghcr.io/open-webui/open-webui:v0.9.2-ollama";

  openwebuiDataDir = "${vars.containers.dataDir}/open-webui/data";
  ollamaDataDir = "${vars.containers.dataDir}/open-webui/ollama-data";
in
{
  options.opts.containers.open-webui = {
    enable = lib.mkEnableOption "open-webui";
    autoStart = lib.mkEnableOption "open-webui auto-start";
  };

  config = lib.mkIf config.opts.containers.open-webui.enable {
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware = {
      graphics.enable = true;
      nvidia = {
        modesetting.enable = true;
        open = false;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
      nvidia-container-toolkit.enable = true;
    };

    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/open-webui 2770 ${vars.username} ${localVars.open-webui.mainGroup} - -"
      "d ${openwebuiDataDir} 2770 ${vars.username} ${localVars.open-webui.mainGroup} - -"
      "Z ${openwebuiDataDir}/* 770 ${vars.username} ${localVars.open-webui.mainGroup} - -"
      "d ${ollamaDataDir} 2770 ${vars.username} ${localVars.open-webui.mainGroup} - -"
      "Z ${ollamaDataDir}/* 770 ${vars.username} ${localVars.open-webui.mainGroup} - -"
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
            group = localVars.open-webui.mainGroup;
          }
          // value
        )
        {
          open-webui-OAUTH_CLIENT_SECRET = {
            sopsFile = ./secrets/OAUTH_CLIENT_SECRET.env;
            format = "dotenv";
          };
        };

    hm = {
      virtualisation.quadlet = {
        containers = {
          open-webui = funcs.containers.mkConfig "root" localVars.open-webui {
            inherit (config.opts.containers.open-webui) autoStart;
            containerConfig = {
              # Passing the Nvidia GPU into this container doesn't work with the uidMaps set,
              #  probably because of a lack of permissions, same as having to set the group to "users".
              # I think this maps the container user to my host user and automaps the rest.
              uidMaps = [ ];
              image = openwebuiImage;
              environmentFiles = [ config.secrets.open-webui-OAUTH_CLIENT_SECRET.path ];
              environments = {
                WEBUI_URL = "https://ai.orangepebble.net";
                ENABLE_OAUTH_SIGNUP = "true";
                OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "true";
                OAUTH_CLIENT_ID = "open-webui";
                OPENID_PROVIDER_URL = "https://auth.orangepebble.net/.well-known/openid-configuration";
                OAUTH_PROVIDER_NAME = "Authelia";
                OAUTH_SCOPES = "openid email profile groups";
                ENABLE_OAUTH_ROLE_MANAGEMENT = "true";
                OAUTH_ALLOWED_ROLES = "openwebui,openwebui-admin";
                OAUTH_ADMIN_ROLES = "openwebui-admin";
                OAUTH_ROLES_CLAIM = "groups";
                OAUTH_CODE_CHALLENGE_METHOD = "S256";
              };
              devices = [
                "nvidia.com/gpu=all"
              ];
              volumes = [
                "${openwebuiDataDir}:/app/backend/data"
                "${ollamaDataDir}:/root/.ollama"
              ];
            };
          };
        };
      };
    };
  };
}
