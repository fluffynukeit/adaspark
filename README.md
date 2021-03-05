# adaspark nix flake

This repo is a nix flake for providing an Ada and SPARK development environment.
There are several (primary) components to this flake:

1. `gnat`, GNAT FSF for compiling Ada code.  Because it is the FSF version, there are no
runtime library license encumbrances. Includes commands `gnatmake`, `gnatbind`, `gnatlink`, `gcc`,
`g++`, etc.
2. `gpr`, GNAT Project Manager, a common multi-project build tool for Ada or mixed 
Ada/C/C++ projects. Includes commands `gprbuild`, `gprls`, etc.
3. `spark`, the SPARK code verification tools. Includes `gnatprove` and `gnat2why`.
4. `adaenv`, a nix build environment like nix's stdenv, but modified so that derivations
that are installed with `gprbuild` as `buildInputs` can be located in the nix store.
5. `adaspark` target that includes 1-3.  This is the default flake output.

Component 4, `adaenv`, is meant to be used to build an Ada project with nix.  If you just
want to build an Ada project without using nix to manage the build, you can include
components 1-3 in a nix shell environment and execute the commands manually, as described
below.

Some utilities commonly found in `gnat` installations like `gnattest`, `gnatchop`, and 
others are not included in this flake.  I hope to add support.

## Enable flakes in nix
At the time of this writing, flakes are an experimental feature of nix.  Please consult
the [flakes wiki entry](https://nixos.wiki/wiki/Flakes) for information on how to enable
them.

## Quickstart shell

On the command line, run `nix shell github:fluffynukeit/adaspark` to build and/or activate
a command line environment that includes gnat tools, gprbuild, and SPARK tools. You can
then use these tools with your own build or development scripts that are executed from
the shell environment.  Any other programs already installed on your system will still be 
accessible.

If you don't want all the components of the built-in `adaspark` environment (for instance,
you don't care about SPARK and don't want to install it), you can specify individual flake
components of your shell environment: `nix shell github:fluffynukeit/adaspark#{gnat,gpr}`

If you want a "pure" shell with nothing from your own system, add the `-i` flag to the 
nix command, which will include only those packages (and their dependents) you specify.
No installed programs from your own system will be accessible.
This is useful for verifying that the dependencies of your projects are all identified.

## Quickstart flake

Example of how to use `adaenv` in a nix flake for a new project (forthcoming).



