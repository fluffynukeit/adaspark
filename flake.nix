{
	description = "Compilers and tools for SPARK2014 Ada development";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/20.09";

	outputs = { self, nixpkgs }: 
		with import nixpkgs { 
			system = "x86_64-linux"; 
		}; let

		# Customized environment supporting gprbuild search paths.

		base_env = gcc10Stdenv;
		adaenv = let
			core = base_env.override { 
				name="adaenv"; 
				cc = gnat10; 
			}; 
			in 
			core // { # use modified mkDerivation function
					mkDerivation = params :
						let new_params = params // {
							# Fix crti.o linker error
							LIBRARY_PATH = params.LIBRARY_PATH or "${adaenv.glibc}/lib";
							# Find installed gpr projects in nix store.
							GPR_PROJECT_PATH = lib.strings.makeSearchPath "share/gpr" 
								(new_params.buildInputs or []);
						};
				in core.mkDerivation new_params;
			};

		# xmlada library needed for gprbuild. Built with bootstrap.

		xmladasrc = fetchgit {
			url = "https://github.com/AdaCore/xmlada.git";
			rev = "refs/tags/xmlada-21.0.0";
			sha256 = "sha256-/KvMMLo1l1SEksFM4dGtobqFi2o67VGQtKGkyfaUdAM=";
		};

		xmlada = adaenv.mkDerivation {
			name = "xmlada";
			buildInputs = [ 
				gprbuild-bootstrap
			];
			src = xmladasrc;
			configurePhase = ''
				./configure --prefix=$prefix BUILD_TYPE=production
			'';
			buildPhase = ''
				make all
			'';
			installPhase = ''
				make install
			'';
		};

		# gprbuild tool

		gprbuildsrc = fetchgit {
			url = "https://github.com/AdaCore/gprbuild.git";
			rev = "refs/tags/v21.0.0";
			sha256 = "sha256-0vqwUVtuiAh73ySfIwmok3wG2Y+ETdgG7Nr8vLTi184=";
		};

		gprconfig_kbsrc = fetchgit {
			url = "https://github.com/AdaCore/gprconfig_kb.git";
			rev = "refs/tags/v21.0.0";
			sha256 = "sha256-7/ZbFOtMQzrajnFNl7lfgMTEcIsSikloh/VG0Jr7FYc=";
		};

		gprbuild-bootstrap = adaenv.mkDerivation {
			name = "gprbuild-bootstrap";
			src = gprbuildsrc;
			patchPhase = "
				patchShebangs ./bootstrap.sh
			";
			dontConfigure = true;
			dontBuild = true;
			installPhase = ''
				./bootstrap.sh \
				--with-xmlada="${xmladasrc}" \
				--with-kb="${gprconfig_kbsrc}" \
				--prefix=$prefix 
			'';
		};

		gprbuild = adaenv.mkDerivation {
			name = "gprbuild";
			buildInputs = [
				xmlada
				gprbuild-bootstrap
				which
			];
			src = gprbuildsrc;
			configurePhase = ''
				make prefix=$prefix BUILD=production setup
			'';
			buildPhase = ''
				make all
			'';
			installPhase = ''
				make install
				mkdir -p $out/share/gprconfig
				cp ${gprconfig_kbsrc}/db/* $out/share/gprconfig/
			'';
		};

		# Spark2014 tools

		spark2014 = adaenv.mkDerivation {
			name = "SPARK2014";
			buildInputs = [ 
				ocaml
				ocamlPackages.ocamlgraph
				ocamlPackages.menhir
				ocamlPackages.zarith
				ocamlPackages.camlzip
				ocamlPackages.ocplib-simplex
				ocamlPackages.findlib
				ocamlPackages.num
				python38
				python38Packages.sphinx
			];
			sparksrc = fetchgit {
					url = "https://github.com/AdaCore/spark2014.git";
					rev = "refs/heads/fsf";
					deepClone = true; # get submodules
					sha256 ="sha256-C/R1RCc/TIJXudTcPk5ArbBSPv5/65lPGQWXz6/vqhk";
			};
			gnatsrc = adaenv.cc.src;
			srcs = [
				sparksrc
				gnatsrc
			];
			sourceRoot = "spark2014";
			configurePhase = "ln -sf ../../gcc-10.2.0 gnat2why/gnat_src && make setup";
		};

		in 

		{
			packages.x86_64-linux.xmlada = xmlada;
			packages.x86_64-linux.gprbuild = gprbuild;
			packages.x86_64-linux.spark2014 = spark2014;
			defaultPackage.x86_64-linux = gprbuild;
		};
}

