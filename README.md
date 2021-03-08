# adaspark nix flake

This repo is a nix flake for providing an Ada and SPARK development environment.
There are several (primary) components to this flake:

1. `gnat`, GNAT FSF for compiling Ada code.  Because it is the FSF version, there are no
runtime library license encumbrances. Includes commands `gnatmake`, `gnatbind`, `gnatlink`, `gcc`,
`g++`, etc.
2. `gpr`, GNAT Project Manager, a common multi-project build tool for Ada or mixed 
Ada/C/C++ projects. Includes commands `gprbuild`, `gprls`, etc.
3. `spark`, the SPARK code verification tools. Includes `gnatprove` and `gnat2why`.
4. `asis`, the ASIS tools. Includes `gnattest`, `gnatcheck`, `gnat2xml`, `gnat2xsd`, `gnatelim`,
  `gnatmetric`, `gnatpp`, `gnatstub`.
5. `adaenv`, a nix build environment like nix's stdenv, but modified so that derivations
that are installed with `gprbuild` as `buildInputs` can be located in the nix store.
It does this by setting `GPR_PROJECT_PATH` to certain nix store locations.
6. `adaspark` target that includes 1-4.  This is the default flake output and gives you
everything you need to build an Ada project without using the nix build system to 
package it.

## Enable flakes in nix
At the time of this writing, flakes are an experimental feature of nix.  Please consult
the [flakes wiki entry](https://nixos.wiki/wiki/Flakes) for information on how to enable
them.

## Quickstart shell

On the command line, run `nix shell github:fluffynukeit/adaspark` to build and/or activate
a command line environment that includes gnat tools, asis tools, gpr, and SPARK. You can
then use these tools with your own build or development scripts that are executed from
the shell environment.  Any other programs already installed on your system will still be 
accessible.

If you don't want all the components of the built-in `adaspark` environment (for instance,
you don't care about SPARK and don't want to install it), you can specify individual flake
components of your shell environment: `nix shell github:fluffynukeit/adaspark#{gnat,gpr}`

If you want a "pure" shell with nothing from your own system, add the `-i` flag to the 
nix command, which will include only those packages (and their dependents) you specify.
No installed programs from your own system will be accessible, not even `ls`!
This is useful for verifying that the dependencies of your projects are all identified.

## Quickstart flake

Example of how to use `adaenv` in a nix flake for a new project (forthcoming).



