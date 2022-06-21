# adaspark nix flake

This repo provides a nix flake for the alire project manager used for Ada and SPARK
development. This allows installation of alire from sources instead of from their
[website](https://alire.ada.dev/) if you prefer.

## Enable flakes in nix
At the time of this writing, flakes are an experimental feature of nix.  Please consult
the [flakes wiki entry](https://nixos.wiki/wiki/Flakes) for information on how to enable
them.

## Quickstart shell

*You do not need to clone this repo to use it.*

On the command line, run `nix shell github:fluffynukeit/adaspark` to enter into a 
subshell that includes alire on your path.  You can then execute the appropriate 
alire commands to manage your project.

## Legacy

Early versions of this flake built an entire FSF Ada/SPARK development toolchain from
source. When AdaCore [endorsed alire as the right tool for project management](https://blog.adacore.com/a-new-era-for-ada-spark-open-source-community),
the flake was simplified to only provide alire, deferring to it for getting 
dependencies and managing builds instead of nix.
