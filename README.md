# lollypops

<p align="center">
  <img src="https://user-images.githubusercontent.com/1719781/176174434-9813865f-9b1d-4a8f-aa45-7c2f30023ae2.svg" height="200"/>  
</p>
<p align="center">
  Lollypop Operations - NixOS Deployment Tool
</p>

<p align="center">
  <a href="https://github.com/pinpox/lollypops/actions/workflows/nix.yml"><img src="https://github.com/pinpox/lollypops/actions/workflows/nix.yml/badge.svg" alt="Contributors badge" /></a>
</p>

## WORK IN PROGRESS

Not usable yet. Development ongoing. It may change and any time. It may destroy
your system or burn everything to the ground.

(PR's welcome)

## Usage

(did you read the above?)

```
# List all Tasks
nix run '.' -- --list-all

# Run specific task for a host
nix run '.' -- ahorn:deploy-secrets

# Run all tasks for a host
nix run '.' -- provision-ahorn
```


## Debuggging
--verbose

# Features

- Stateless
- Parallel execution
- Secret provisioning from any source

# Other

```nix
# flake.nix
# TODO flake input and module import

apps = {
		default = lollypops.apps."${system}".default { configFlake = self; };
};
```

Define your secrets in your host's `configuration.nix`. See `module.nix` for all
possible options.

```nix
# configuration.nix

lollypops.secrets.files = {
	secret1 = {
		cmd = "pass test-password";
		path = "/tmp/secretfile";
	};
};


  lollypops.secrets.files = {
    secret1 = {
      cmd = "pass test-password";
      path = "/tmp/testfile5";
    };

    "nixos-secrets/ahorn/ssh/borg/public" = {
      path = "/tmp/testfile7";
    };
  };
```

