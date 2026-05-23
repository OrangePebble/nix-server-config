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
  #  https://github.com/TecharoHQ/anubis/tags
  anubisImage = "ghcr.io/techarohq/anubis:v1.25.0";

  anubisDataDir = "${vars.containers.dataDir}/anubis/data";
in
{
  options.opts.containers.anubis = {
    enable = lib.mkEnableOption "anubis";
    autoStart = lib.mkEnableOption "anubis auto-start";
  };

  config = lib.mkIf config.opts.containers.anubis.enable {
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/anubis 2770 ${vars.username} ${localVars.anubis.mainGroup} - -"
      "d ${anubisDataDir} 2770 ${vars.username} ${localVars.anubis.mainGroup} - -"
      "Z ${anubisDataDir}/* 770 ${vars.username} ${localVars.anubis.mainGroup} - -"
      "d ${vars.containers.dataDir}/anubis/socket 2770 ${vars.username} ${localVars.anubis.mainGroup} - -"
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
            group = localVars.anubis.mainGroup;
          }
          // value
        )
        {
          # Random string:
          # `LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\\]^_{|}~' </dev/urandom | head -c 32`
          anubis-private-key.sopsFile = ./secrets/private_key;
        };
    hm = {
      virtualisation.quadlet = {
        containers = {
          anubis = funcs.containers.mkConfig "1000" localVars.anubis {
            inherit (config.opts.containers.anubis) autoStart;
            containerConfig = {
              image = anubisImage;
              environments = {
                COOKIE_DOMAIN = "orangepebble.net";
                REDIRECT_DOMAINS = "orangepebble.net,*.orangepebble.net";
                TARGET = "unix:/run/anubis/nginx.sock";
                SERVE_ROBOTS_TXT = "true";
                DIFFICULTY = "10"; # Couldn't find what would be a good value so I just chose 10.
                ED25519_PRIVATE_KEY_HEX_FILE = config.secrets.anubis-private-key.path;
              };
              volumes = [
                "${anubisDataDir}:/data"
                "${vars.containers.dataDir}/anubis/socket:/run/anubis"
                "${config.secrets.anubis-private-key.path}:${config.secrets.anubis-private-key.path}"
              ];
            };
          };
        };
      };
    };
  };
}
