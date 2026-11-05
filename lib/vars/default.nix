_:
let
  # Setting this in 'let in' so the values can be used easier in imports.
  default = rec {
    hostname = "server";
    username = "pebble";
  };
  containers = import ./containers.nix default;
in
default // containers
