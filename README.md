# nixos-deploy
![workflow](https://github.com/misuzu/nixos-deploy/actions/workflows/nix.yml/badge.svg)

`nixos-deploy` is a NixOS deployment tool build which provides parallel
deployment as a thin, pure nix wrapper around [go-task](https://taskfile.dev/).

The deployment options are specified in each host's `flake.nix`
configuration. nixos-deploy then takes all `nixosConfigurations` and generates a
[go-task](https://taskfile.dev/) yaml configuration internally on the fly when
executed.

`nixos-deploy` is a fork of [lollypops](https://github.com/pinpox/lollypops).

## Features

- Stateless
- Parallel execution
- Configured in nix
- Minimal overhead and easy debugging
- Fully flake compatible

## Usage

After configuration (see below) you will be able to run `nixos-deploy` passing it one
or more arguments to specify which tasks to run. To see what deployment targets
are available use `--list`. Arguments are passed verbantim to `go-task`, use `--help`
to get a full list of options including output customizaion and debugging
capabilities or consult it's [documentation](https://taskfile.dev/usage/)

```sh
# List all deployment targets
$ nix run '.' -- --list
task: Available tasks for this project:
* ahorn:    Deploy ahorn
* birne:    Deploy birne
* default:  Deploy all hosts
```

The above shows two hosts `ahorn` and `birne` with their corresponding tasks.
To provision a single host run:

```sh
$ nix run '.' -- ahorn
```

There is also a special task called `default`, which will deploy all hosts.
It will be executed by default if no deployment targets are specified:

```sh
$ nix run '.'
```

### Override switch-to-configuration action

By default the deploy step will run `switch-to-configuration switch` to activate the
configuration. It is possible to override the default
(`switch`) action for testing, e.g. to set it to `boot`, `test` or
`dry-activate` by setting the environment variable `DEPLOY_ACTION` to the
desired action, e.g.

```sh
$ DEPLOY_ACTION=dry-activate nix run '.'
```

## Configuration

Add `nixos-deploy` to your flake's inputs as you would for any dependency and import
the `nixos-deploy` module in required hosts configured in your `nixosConfigurations`.

Then, use the the `apps` attribute set to expose the `nixos-deploy` commands.
Here a single parameter is requied: `configFlake`. This is the flake containing
your `nixosConfigurations` from which `nixos-deploy` will build it's task
specifications. In most cases this will be `self` because the app configuration
and the `nixosConfigurations` are defined in the same flake.

A complete minimal example:

```nix
{
  inputs = {
    nixos-deploy.url = "github:misuzu/nixos-deploy";
    # Other inputs ...
  };

  outputs = { nixpkgs, nixos-deploy, self, ... }: {

    nixosConfigurations = {

      host1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-deploy.nixosModules.nixos-deploy
          ./configuration1.nix
        ];
      };

      host2 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          nixos-deploy.nixosModules.nixos-deploy
          ./configuration2.nix
        ];
      };

      host3 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration3.nix
        ];
      };
    };

    apps."x86_64-linux".default = nixos-deploy.apps."x86_64-linux".default { configFlake = self; };
  };
}
```

With this you are ready to start using `nixos-deploy`. The above already should allow
you to list the tasks for two hosts with `--list`

```sh
$ nix run '.' --show-trace -- --list
task: Available tasks for this project:
* host1:    Deploy host1
* host2:    Deploy host2
* default:  Deploy all hosts
```

To actually do something useful you can now use the options provided by the
`nixos-deploy` module in your `configuration.nix` (or wherever your the
configuration of your host is specified).

### Deployment

Specify how and where to deploy. The default values may be sufficient here in
a lot of cases.

```nix
nixos-deploy.deployment = {
  # ssh connection parameters
  host = "${config.networking.hostName}";
  # you gonna need a user in the `wheel` group if you don't want to use root user
  # don't forget to also tell nix that your user is trusted
  # setting `nix.settings.trusted-users = [ "@wheel" ];` should do the trick
  user = "root";
};
```

By default if local host architecture is not the one that is on a target host
`nixos-deploy` will use target host as remote builder.
Set `nixos-deploy.config.localBuildOnly` to `true` and configure [remote builder](https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds.html)
if you don't want to build on target hosts.

### Debugging

`nixos-deploy` hides the executed commands in the default output. To enable full
logging use the `--verbose` flag which is passed to `go-task`.

### Contributing

Pull requests are very welcome!

This software is under active development. If you find bugs, please open an
issue and let me know. Open to feature request, tips and constructive criticism.

Let me know if you run into problems
