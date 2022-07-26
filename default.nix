{ stdenv
, lib
, hostPlatform
, writeText
, writeShellScriptBin
, nixFlakes
, go-task
, configFlake
}:
let
  # ignore hosts without `nixos-deploy` module
  deploymentTargets = lib.filterAttrs
    (hostName: hostConfig: lib.hasAttr "nixos-deploy" hostConfig.config )
    configFlake.nixosConfigurations;
  mkTaskFileForHost = hostName: hostConfig: writeText "Tasks-${hostName}.yml"
    (builtins.toJSON {
      version = "3";
      output = "prefixed";

      vars = with hostConfig.config.nixos-deploy; {
        REMOTE_HOST = deployment.host;
        REMOTE_USER = ''{{default "${deployment.user}" .REMOTE_USER}}'';
        DEPLOY_ACTION = ''{{default "switch" .DEPLOY_ACTION}}'';
      };

      tasks = let
        remoteBuild = (!hostConfig.config.nixos-deploy.config.localBuildOnly) && hostConfig.pkgs.hostPlatform.system != hostPlatform.system;
      in {
        _build = {
          cmds = [
            ''
              echo "Building ${if remoteBuild then "remotely" else "locally"}: ${hostName}"

              system=$(${nixFlakes}/bin/nix --experimental-features 'flakes nix-command' build \
                -L \
                --no-link \
                --print-out-paths \
                ${lib.optionalString remoteBuild
                  "--eval-store auto --store ssh-ng://{{.REMOTE_USER}}@{{.REMOTE_HOST}}"
                } \
                ${configFlake}#nixosConfigurations.${hostName}.config.system.build.toplevel)

              echo $system > {{.TASK_TEMP_DIR}}/${hostName}
            ''
          ];
        };
        _deploy = {
          cmds = [
            ''
              echo "Deploying: ${hostName}"

              system=$(cat {{.TASK_TEMP_DIR}}/${hostName})

              ${lib.optionalString (!remoteBuild) ''
                ${nixFlakes}/bin/nix --experimental-features 'flakes nix-command' copy \
                  --no-check-sigs \
                  --substitute-on-destination \
                  --to ssh-ng://{{.REMOTE_USER}}@{{.REMOTE_HOST}} \
                  $system
              ''}

              if [[ {{.DEPLOY_ACTION}} = switch || {{.DEPLOY_ACTION}} = boot ]]; then
                ssh {{.REMOTE_USER}}@{{.REMOTE_HOST}} '$(which sudo)' "nix-env -p /nix/var/nix/profiles/system --set $system"
              fi

              ssh {{.REMOTE_USER}}@{{.REMOTE_HOST}} '$(which sudo)' "/nix/var/nix/profiles/system/bin/switch-to-configuration {{.DEPLOY_ACTION}}"
            ''
          ];
        };
      };
    });

  # Taskfile passed to go-task
  taskfile = writeText
    "Taskfile.yml"
    (builtins.toJSON {
      version = "3";
      output = "prefixed";

      # Don't print excuted commands. Can be overridden by -v
      silent = true;

      # Import the taks once for each host, setting the HOST variable.
      includes = lib.mapAttrs
        (name: value: { taskfile = mkTaskFileForHost name value; })
        deploymentTargets;

      tasks = {
        # Add special task called "default" which has all hosts as
        # dependency to deploy all hosts at once
        default = {
          desc = "Deploy all hosts";
          cmds = [
            { task = "_build"; }
            { task = "_deploy"; }
          ];
        };
        _build.deps = map (name: "${name}:_build") (lib.attrNames deploymentTargets);
        _deploy.deps = map (name: "${name}:_deploy") (lib.attrNames deploymentTargets);
      } // lib.mapAttrs
        # Define grouped tasks to run all tasks for one host.
        # E.g. to make a complete deployment for host "server01":
        # `nix run '.' -- server01`
        (name: value: {
          desc = "Deploy ${name}";
          cmds = [
            {
              task = "${name}:_build";
            }
            {
              task = "${name}:_deploy";
            }
          ];
        })
        deploymentTargets;
    });
in
writeShellScriptBin "nixos-deploy" ''
  export TASK_TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'nixos-deploy')
  trap "rm -rf $TASK_TEMP_DIR" EXIT
  ${go-task}/bin/task -t ${taskfile} -p "$@"
''
