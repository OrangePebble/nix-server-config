# Alternative to Perplexity, an AI service that searches the internet.
# This solution is quite janky but does the job.
{
  vars,
  funcs,
  config,
  lib,
  pkgs,
  ...
}:
let
  localVars = vars.containers.containers;

  # Find new versions for the following two at:
  #  https://hub.docker.com/r/itzcrazykns1337/vane/tags
  # WARN: When updating this also update the hash in the fetchFromGitHub below.
  vaneVersion = "v1.12.2";
  # Find new versions at:
  #  https://hub.docker.com/r/ollama/ollama/tags
  ollamaImage = "docker.io/ollama/ollama:0.30.0-rc11";

  vaneDataDir = "${vars.containers.dataDir}/vane/data";
  ollamaDataDir = "${vars.containers.dataDir}/vane/ollama-data";
in
{
  options.opts.containers.vane = {
    enable = lib.mkEnableOption "vane";
    autoStart = lib.mkEnableOption "vane auto-start";
  };

  config = lib.mkIf config.opts.containers.vane.enable {
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
      "d ${vars.containers.dataDir}/vane 2770 ${vars.username} ${localVars.vane.mainGroup} - -"
      "d ${vaneDataDir} 2770 ${vars.username} ${localVars.vane.mainGroup} - -"
      "Z ${vaneDataDir}/* 770 ${vars.username} ${localVars.vane.mainGroup} - -"
      "d ${ollamaDataDir} 2770 ${vars.username} ${localVars.vane-ollama.mainGroup} - -"
      "Z ${ollamaDataDir}/* 770 ${vars.username} ${localVars.vane-ollama.mainGroup} - -"
    ];

    hm = {
      virtualisation.quadlet = {
        builds = {
          # The URLs used can only be changed at build time for some weird/lazy reason.
          vane = {
            # INFO: This takes way too long so, when needed, just run the command in:
            #  ~/.config/systemd/user/vane-build.service.d/override.conf
            autoStart = false;
            buildConfig = {
              tag = "vane:${vaneVersion}";
              workdir = "${pkgs.fetchFromGitHub {
                owner = "ItzCrazyKns";
                repo = "Vane";
                rev = vaneVersion;
                hash = "sha256-mQx2ZTUkTRbtcOZciyRpjH6G391oslAXRzjWBO1NKg8=";
              }}";
              buildArgs = {
                NEXT_PUBLIC_API_URL = "https://vane:3000/api";
                NEXT_PUBLIC_WS_URL = "wss://vane:3000/ws";
              };
            };
          };
        };
        containers = {
          vane = funcs.containers.mkConfig "root" localVars.vane {
            inherit (config.opts.containers.vane) autoStart;
            containerConfig = {
              # image = config.hm.virtualisation.quadlet.builds.vane.ref;
              image = "localhost/vane:${vaneVersion}";
              environments = {
                TZ = "Europe/Lisbon";
              };
              volumes = [
                "${vaneDataDir}:/home/vane/data"
              ];
              networks = [
                "vane"
              ];
            };
          };
          # Get models on:
          #  https://ollama.com/search
          #  https://huggingface.co
          # The non-embedding model requires tools support.
          # Make sure to choose models with parameters small enough for the GPU.
          # Add models by running `podman exec -it vane-ollama ollama pull <model>`.
          # Remove models by running `podman exec -it vane-ollama ollama rm <model>`.
          # List models by running `podman exec -it vane-ollama ollama list`.
          vane-ollama = funcs.containers.mkConfig "ubuntu" localVars.vane-ollama {
            inherit (config.opts.containers.vane) autoStart;
            containerConfig = {
              # Passing the Nvidia GPU into this container doesn't work with the uidMaps set,
              #  probably because of a lack of permissions, same as having to set the group to "users".
              # I think this maps the container user to my host user and automaps the rest.
              uidMaps = [ ];
              image = ollamaImage;
              devices = [
                "nvidia.com/gpu=all"
              ];
              volumes = [
                "${ollamaDataDir}:/home/ubuntu/.ollama"
              ];
              networks = [ "vane" ];
            };
          };
        };
        networks.vane = { };
      };
    };
  };
}
