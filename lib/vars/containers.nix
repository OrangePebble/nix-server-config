vars:
let
  containers = {
    # How many uids and gids the containers will have allocated to them.
    # Will map from 0-1999. More than enough for most containers.
    uidGidCount = 2000;
    # The groups defined in 'groups' start with this gid.
    startGid = 1001;
    # Not all containers need special groups because they don't use volumes,
    #  but I'll add them just in case.
    # WARN: To remove container groups just rename them to a placeholder name so that the rest keep
    #  the correct GID, unless it is the last one which can just be removed.
    # When adding more container groups later, these renamed groups can be reused.
    groups = [
      "public" # For everything that may be exposed to the internet.
      "karakeep"
      "karakeep-chrome"
      "karakeep-meilisearch"
      "copyparty"
      "immich"
      "immich-machine-learning"
      "immich-database"
      "swag"
      "authelia"
      "authelia-valkey"
      "authelia-postgres"
      "lldap"
      "lldap-postgres"
      "navidrome"
    ];
    # Unfortunately, I need to make this a list if I want to keep the order in
    #  the modifying function below. If I used an attrset, they would be sorted
    #  alphabetically and so the subuid and subgid used aren't fixed.
    # WARN: To remove container groups just replace them with a placeholder so that the rest keep
    #  the correct index, unless it is the last one, which can just be removed.
    # When adding more containers later, the placeholder attrsets can be reused.
    containers = [
      {
        karakeep = {
          mainGroup = "karakeep";
          # For the common .env secret file.
          extraGroups = [ "karakeep-meilisearch" ];
        };
      }
      { karakeep-chrome.mainGroup = "karakeep-chrome"; }
      { karakeep-meilisearch.mainGroup = "karakeep-meilisearch"; }
      { socket-proxy.mainGroup = "users"; }
      { blocky = { }; }
      {
        copyparty = {
          mainGroup = "copyparty";
          extraGroups = [ "public" ];
        };
      }
      {
        immich = {
          mainGroup = "immich";
          extraGroups = [ "public" ];
        };
      }
      { immich-machine-learning.mainGroup = "immich-machine-learning"; }
      { immich-redis = { }; }
      { immich-database.mainGroup = "immich-database"; }
      { swag.mainGroup = "swag"; }
      { authelia.mainGroup = "authelia"; }
      { authelia-valkey.mainGroup = "authelia-valkey"; }
      { authelia-postgres.mainGroup = "authelia-postgres"; }
      { lldap.mainGroup = "lldap"; }
      { lldap-postgres.mainGroup = "lldap-postgres"; }
      {
        navidrome = {
          mainGroup = "navidrome";
          extraGroups = [ "public" ];
        };
      }
      { vane.mainGroup = "users"; }
      { vane-ollama.mainGroup = "users"; }
    ];
    dataDir = "${vars.homeDirectory}/container-data";
    publicDir = "${vars.homeDirectory}/public";
    rootCapabilities = [
      "CHOWN"
      "DAC_OVERRIDE"
      "FOWNER"
      "FSETID"
      "KILL"
      "NET_BIND_SERVICE"
      "SETFCAP"
      "SETGID"
      "SETPCAP"
      "SETUID"
      "SYS_CHROOT"
    ];
  };
in
{
  containers =
    with builtins;
    mapAttrs (
      name: value:
      if name == "containers" then
        listToAttrs (
          genList (
            i:
            let
              containerName = elemAt (attrNames (elemAt value i)) 0;
              containerValue = (elemAt value i).${containerName};
            in
            {
              name = containerName;
              value = {
                i = i;
                mainGroup = containerValue.mainGroup or null;
                extraGroups = containerValue.extraGroups or [ ];
              };
            }
          ) (length value)
        )
      else
        value
    ) containers;
}
