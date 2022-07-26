{ config, pkgs, lib, ... }:
with lib;
{
  options.nixos-deploy = {
    config = {
      localBuildOnly = mkOption {
        type = types.bool;
        default = false;
        description = "Build locally even if target host has different architecture";
      };
    };
    deployment = {
      host = mkOption {
        type = types.str;
        default = "${config.networking.hostName}";
        description = "Host to deploy to";
      };
      user = mkOption {
        type = types.str;
        default = "root";
        description = "User to deploy as";
      };
    };
  };
}
