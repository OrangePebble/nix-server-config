{
  vars,
  funcs,
  config,
  lib,
  ...
}:
let
  localVars = vars.containers.containers.swag;
  # Find new versions at:
  #  https://github.com/linuxserver/docker-swag/releases
  swagImage = "lscr.io/linuxserver/swag:5.5.0";
  configDir = funcs.relativeToAbsoluteConfigPath ./config;
  defaultConfigDir = "${vars.containers.dataDir}/swag/config";
  modCacheDir = "${vars.containers.dataDir}/swag/modcache";
  symlinks = {
    # This symlink gets turned into a regular file when swag starts up, so to
    #  modify it you'll have to recreate the symlink by either restarting or
    #  running `systemd-tmpfiles --create`.
    "${defaultConfigDir}/nginx/nginx.conf" = "${configDir}/nginx.conf";

    "${defaultConfigDir}/dns-conf/cloudflare.ini" = toString config.secrets.certbot-cloudflare.path;
    "${defaultConfigDir}/tunnelconfig.yml" = "${configDir}/tunnelconfig.yml";
    "${defaultConfigDir}/nginx/site-confs/default.conf" = "${configDir}/default.conf";
    "${defaultConfigDir}/nginx/ssl.conf" = "${configDir}/ssl.conf";
    "${defaultConfigDir}/nginx/dbip.conf" = "${configDir}/dbip.conf";
    "${defaultConfigDir}/dbip-blocks.conf" = "${configDir}/dbip-blocks.conf";
    "${defaultConfigDir}/internal-only.conf" = "${configDir}/internal-only.conf";
    "${defaultConfigDir}/nginx/proxy-confs/dashboard.subdomain.conf" =
      "${configDir}/dashboard.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/authelia.subdomain.conf" =
      "${configDir}/authelia.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/immich.subdomain.conf" =
      "${configDir}/immich.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/copyparty.subdomain.conf" =
      "${configDir}/copyparty.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/lldap.subdomain.conf" = "${configDir}/lldap.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/navidrome.subdomain.conf" =
      "${configDir}/navidrome.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/karakeep.subdomain.conf" =
      "${configDir}/karakeep.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/open-webui.subdomain.conf" =
      "${configDir}/open-webui.subdomain.conf";
    "${defaultConfigDir}/nginx/proxy-confs/forgejo.subdomain.conf" =
      "${configDir}/forgejo.subdomain.conf";
  };
  containerUID = "1000";
  hostUID = toString (
    (lib.toInt containerUID)
    + vars.containers.uidGidCount * localVars.i
    + (builtins.elemAt config.users.users.${vars.username}.subUidRanges 0).startUid
  );
in
{
  options.opts.containers.swag = {
    enable = lib.mkEnableOption "SWAG";
    autoStart = lib.mkEnableOption "SWAG auto-start";
  };

  config = lib.mkIf config.opts.containers.swag.enable {
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/swag 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${defaultConfigDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${modCacheDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "Z ${defaultConfigDir}/* 770 ${hostUID} ${localVars.mainGroup} - -"
      # Symlinks aren't created if the destination directories have a different owner.
      "d ${defaultConfigDir}/dns-conf 770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${defaultConfigDir}/nginx 770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${defaultConfigDir}/nginx/site-confs 770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${defaultConfigDir}/nginx/proxy-confs 770 ${vars.username} ${localVars.mainGroup} - -"

      "d ${configDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "Z ${configDir}/* 770 ${vars.username} ${localVars.mainGroup} - -"
    ]
    ++ (map (x: "L+ ${x.name} - - - - ${x.value}") (lib.attrsToList symlinks));
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
            group = localVars.mainGroup;
          }
          // value
        )
        {
          # Random string:
          # `LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\\]^_{|}~' </dev/urandom | head -c 32`
          # Automatically encrypt string with sops:
          # `sops --input-type binary -e <(LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\\]^_{|}~' </dev/urandom | head -c 32) > <file path>`
          certbot-cloudflare = {
            sopsFile = ./secrets/cloudflare.ini;
            format = "ini";
          };
          swag-cloudflare = {
            sopsFile = ./secrets/cloudflare.env;
            format = "dotenv";
          };
        };
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    hm =
      let
        networks = {
          # container = "network"
          immich = "swag-immich";
          copyparty = "swag-copyparty";
          authelia = "swag-authelia";
          lldap = "swag-lldap";
          navidrome = "swag-navidrome";
          karakeep = "swag-karakeep";
          open-webui = "swag-open-webui";
          forgejo = "swag-forgejo";
          # WARN: Everytime you change this, you need to remove
          #  '${defaultConfigDir}/nginx/resolver.conf' or else the
          #  new networks aren't used.
        };
      in
      {
        virtualisation.quadlet = {
          containers = {
            swag = funcs.containers.mkConfig "root" localVars {
              autoStart = config.opts.containers.swag.autoStart;
              serviceConfig = {
                RestartSec = "10";
                Restart = "always";
              };
              containerConfig = {
                image = swagImage;
                publishPorts = [
                  "443:443"
                  "80:80"
                ];
                environments = {
                  PUID = containerUID;
                  PGID = funcs.containers.getContainerGid localVars.mainGroup;
                  TZ = "Europe/Lisbon";
                  URL = "orangepebble.net";
                  SUBDOMAINS = "wildcard";
                  VALIDATION = "dns";
                  # Even though my domain provider is porkbun, my DNS is being managed by cloudflare
                  DNSPLUGIN = "cloudflare";
                  # DOCKER_MODS = "linuxserver/mods:swag-dashboard|linuxserver/mods:swag-dbip";
                  DOCKER_MODS = "linuxserver/mods:swag-dashboard|linuxserver/mods:swag-dbip|linuxserver/mods:universal-cloudflared|linuxserver/mods:swag-cloudflare-real-ip";
                  # https://www.linuxserver.io/blog/zero-trust-hosting-and-reverse-proxy-via-cloudflare-swag-and-authelia
                  # The only thing I've changed in the cloudflare dashboard
                  #  (besides the required settings for the tunnel) was to
                  #  to create a caching rule to bypass all caching. Both so
                  #  that personal things aren't cached and because its against
                  #  their TOS to cache things like piracy.
                  # I'm not totally confortable with the way the cloudflare
                  #  tunnel decrypts everything on the cloudflare servers, but
                  #  it does mitigate attacks substantially.
                  # The worst case scenario with cloudflare is that they
                  #  collect personal data and maybe ban me, the worst case
                  #  scenario with port forwarding is being DDoSed and malicious
                  #  actors finding vulnerabilities with my router and config
                  #  and losing my data, which is substantially worse.
                  CF_TUNNEL_NAME = "server";
                  FILE__CF_TUNNEL_CONFIG = "/config/tunnelconfig.yml";
                };
                environmentFiles = [ (toString config.secrets.swag-cloudflare.path) ];
                addHosts = [ "orangepebble.net:127.0.0.1" ];
                volumes = [
                  "${defaultConfigDir}:/config"
                  "${modCacheDir}:/modcache"
                ]
                ++ (map (x: "${x}:${x}") (builtins.attrValues symlinks));
                networks = builtins.attrValues networks;
                addCapabilities = [ "NET_ADMIN" ];
              };
            };
          }
          // (builtins.mapAttrs (_: value: { containerConfig.networks = [ value ]; }) networks);
          networks = builtins.listToAttrs (
            map (x: {
              name = x;
              value = { };
            }) (builtins.attrValues networks)
          );
        };
      };
  };
}
