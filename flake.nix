{
	description = "Compilers and tools for SPARK2014 Ada development";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/20.09";

	outputs = { self, nixpkgs }: 
		with import nixpkgs { 
			system = "x86_64-linux"; 
		}; let

		python = python27;
		pythonPackages = python27Packages;

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
						assert lib.asserts.assertMsg (params ? name) 
							"Attribute 'name' of derivation must be specified!"; let
						new_params = params // {
							# Fix crti.o linker error
							LIBRARY_PATH = params.LIBRARY_PATH or "${adaenv.glibc}/lib";
							# Find installed gpr projects in nix store.
							GPR_PROJECT_PATH = lib.strings.makeSearchPath "share/gpr" 
								(new_params.buildInputs or []);
						};
				in core.mkDerivation new_params;
			};

		# xmlada library needed for gprbuild. Built with bootstrap.

		xmladasrc = fetchFromGitHub {
			owner = "AdaCore";
			repo = "xmlada";
			rev = "xmlada-21.0.0";
			sha256 = "sha256-/KvMMLo1l1SEksFM4dGtobqFi2o67VGQtKGkyfaUdAM=";
		};

		xmlada = adaenv.mkDerivation {
			name = "xmlada";
			version = "21.0.0";
			buildInputs = [ 
				gprbuild-bootstrap
			];
			src = xmladasrc;
			configurePhase = ''
				./configure --prefix=$prefix --enable-build=Production
			'';
			buildPhase = ''
				make all
			'';
			installPhase = ''
				make install
			'';
		};

		# gprbuild tool

		gprbuildsrc = fetchFromGitHub {
			owner = "AdaCore";
			repo = "gprbuild";
			rev = "v21.0.0";
			sha256 = "sha256-0vqwUVtuiAh73ySfIwmok3wG2Y+ETdgG7Nr8vLTi184=";
		};

		gprconfig_kbsrc = fetchFromGitHub {
			owner = "AdaCore";
			repo = "gprconfig_kb";
			rev = "v21.0.0";
			sha256 = "sha256-7/ZbFOtMQzrajnFNl7lfgMTEcIsSikloh/VG0Jr7FYc=";
		};

		gprbuild-bootstrap = adaenv.mkDerivation {
			name = "gprbuild-bootstrap";
			version = "21.0.0";
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
			version = "21.0.0";
			buildInputs = [
				gprbuild-bootstrap
				xmlada
				which
			];
			src = gprbuildsrc;
			configurePhase = ''
				make prefix=$prefix BUILD=production setup
			'';
			buildPhase = ''
				make all libgpr.build
			'';
			installPhase = ''
				make install libgpr.install
				mkdir -p $out/share/gprconfig
				cp ${gprconfig_kbsrc}/db/* $out/share/gprconfig/
			'';
		};

		# gnatcoll-core

		gnatcoll-coresrc = fetchFromGitHub {
			owner = "AdaCore";
			repo = "gnatcoll-core";
			rev = "v21.0.0";
			sha256 = "sha256-D0/dMEYjQ0+0NfgfvlEVUQMTf8SQ9lWeNHm5n5IQ+kk=";
		};

		gnatcoll-core = adaenv.mkDerivation {
			name = "gnatcoll-core";
			version = "21.0.0";
			buildInputs = [
				gprbuild
				which
				xmlada
			];
			src = gnatcoll-coresrc;
			configurePhase = ''
				make prefix=$prefix BUILD=PROD setup
			'';
		};


		# Spark2014 tools
		sparksrc = fetchFromGitHub {
				owner = "AdaCore";
				repo = "spark2014";
				rev = "d846b3d10503db9567a509bff2982366d8caa131"; # 20.2, to match gcc 10.2
				sha256 = "sha256-SaJ8nGGn21dtHIsE02GslefUaYZG7JX//o7rB+AsndM=";
				fetchSubmodules = true;
		};

		gnatsrc = adaenv.cc.cc.src;

		spark2014 = adaenv.mkDerivation {
			name = "SPARK2014";
			version = "fsf";
			buildInputs = [ 
				ocaml
				ocamlPackages.ocamlgraph
				ocamlPackages.menhir
				ocamlPackages.zarith
				ocamlPackages.camlzip
				ocamlPackages.ocplib-simplex
				ocamlPackages.findlib
				ocamlPackages.num
				gnatcoll-core
				python
				pythonPackages.sphinx
				gprbuild
				xmlada
			];
			srcs = [
				sparksrc
				gnatsrc # need to list here to get local uncompressed copy
			];
			sourceRoot = "source";
			configurePhase = ''
				ln -s ../../gcc-10.2.0/gcc/ada gnat2why/gnat_src \
				&& make setup
			'';
			installPhase = ''
				make install-all
				cp -a ./install/. $out
			'';
		};

		in 

		{
			packages.x86_64-linux.xmlada = xmlada;
			packages.x86_64-linux.gprbuild = gprbuild;
			packages.x86_64-linux.gnatcoll-core = gnatcoll-core;
			packages.x86_64-linux.spark2014 = spark2014;
			defaultPackage.x86_64-linux = spark2014;
		};
}

