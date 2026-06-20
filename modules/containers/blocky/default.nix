# Info about Blocky, DNS, and routers at the end of the file.
# On my router I've set:
#  - Primary DNS on the Internet section to Mullvad
#  - Secondary DNS on the Internet section to Control D
#  - Default gateway to 192.168.1.2 and IP address pool 192.168.1.3-192.168.1.253
#    - The plan was to keep 192.168.1.1 my ISP router's IP, but I didn't figure
#    out how to make it accessible. And yes, the ISP router's web UI is still
#    available, I had to manually disable WIFI after setting bridge mode to 1
#    port.
#  - Reserved IP address 192.168.1.3 to the desktop.
#  - Reserved IP address 192.168.1.4 to the server.
#  - Reserved IP address 192.168.1.5 to the printer.
# I've set the primary and secondary DNSs on both my router and blocky to the
#  unfiltered versions (without adblocking) because it gives me more control
#  over what to block/allow, in case I need access to something blocked.
{
  vars,
  funcs,
  config,
  lib,
  ...
}:
let
  localVars = vars.containers.containers.blocky;

  # Find new versions at:
  #  https://github.com/0xERR0R/blocky/releases
  blockyImage = "ghcr.io/0xerr0r/blocky:v0.32.1";

  blockyConfigFile = funcs.relativeToAbsoluteConfigPath ./config.yaml;
in
{
  options.opts.containers.blocky = {
    enable = lib.mkEnableOption "blocky";
    autoStart = lib.mkEnableOption "blocky auto-start";
  };

  config = lib.mkIf config.opts.containers.blocky.enable {
    systemd.tmpfiles.rules = [
      # Blocky doesn't use groups so make sure the config file is readable by anyone.
      "z ${blockyConfigFile} 644 ${vars.username} users - -"
    ];
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
    hm = {
      virtualisation.quadlet = {
        containers = {
          # https://0xerr0r.github.io/blocky/latest/
          # I think the blocky container might just be a single binary, but
          #  the image layers (I think equivalent to a compose file) sets
          #  user to 100. I don't think it uses any group though.
          blocky = funcs.containers.mkConfig null localVars {
            autoStart = config.opts.containers.blocky.autoStart;
            containerConfig = {
              image = blockyImage;
              publishPorts = [
                "53:53/tcp"
                "53:53/udp"
                "4000:400/tcp"
              ];
              environments = {
                TZ = "Europe/Lisbon";
              };
              volumes = [
                "${blockyConfigFile}:/app/config.yml:ro"
              ];
            };
          };
        };
      };
    };
  };
}
# I've chosen Blocky as my DNS server instead of Pi-hole or TechnitiumDNS
#  mostly because it was created with containers in mind and all its
#  configuration is set in a file.
# I'm using the blocklists from 'https://github.com/hagezi/dns-blocklists' as
#  they seem popular and well regarded. This is also where I found the DNS
#  server alternatives.
# I'll maybe host a recursive DNS myself, as if the server isn't working my
#  family can still use the router's secondary DNS, but it is quite resource
#  intensive and slow on first request, and not that big of a privacy plus
#  as there are public and free DNS servers that at least say they're private.
# Here are some of the public, free, and private DNS servers I've found:
#   - Cloudflare : https://one.one.one.one/dns/
#   - Mullvad : https://mullvad.net/en/help/dns-over-https-and-dns-over-tls
#   - Control D : https://controld.com/free-dns
#   - Quad9 : https://quad9.net
#   - AdGuard : https://adguard-dns.io/en/public-dns.html
# All of these DNS servers have versions that block ads/malware, but I won't
#  use them in order to have more control over what's blocked.
# Of these free DNS servers, according to my testing, the fastest ones are (in
#  order): Cloudflare, Control D, Mullvad, Quad9, AdGuard.
# I've tried mainly using Control D, but it stopped working properly.
# Cloudflare is the only one from a BIG for profit company, but their website
#  does say they don't log things and are private (and they're not known to be
#  scummy). Also, I'm using a Cloudflare Tunnel to expose my services, and that
#  is trusting Cloudflare on another level, so if I'm trusting it the tunnel
#  I might as well trust the DNS.
# https://www.reddit.com/r/pihole/comments/1ajunoc/whats_the_difference_between_dns_in_dhcp_server/
#  I can set DNS servers on two different spots in my router, on the DHCP server
#  and on the Internet section. The difference between the 2 is that those on
#  the Internet section are WAN only (can't use private addresses like one to
#  this server), and the ones in the DHCP server come before it, if DNS servers
#  aren't set in the DHCP server, the router announces itself as the DNS server
#  and redirects to the ones in the Internet section.
# Now, if I want the absolute certainty that all DNS requests pass through my
#  server, I have to set all DNS servers on the DHCP server to my server. But
#  this makes it so that when the server goes down, DNS is down, and there is
#  no internet.
#  So, in order to have redundancy, I'll just leave the secondary DNS server
#   on the DHCP server empty, which has been working fine.
