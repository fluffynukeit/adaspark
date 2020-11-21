{
	description = "A very basic flake";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/20.09";

	outputs = { self, nixpkgs }: 
		with import nixpkgs { 
			system = "x86_64-linux"; 
		}; let

		gprbuildsrc = fetchgit {
			url = "https://github.com/AdaCore/gprbuild.git";
			rev = "refs/tags/v21.0.0";
			sha256 = "sha256-0vqwUVtuiAh73ySfIwmok3wG2Y+ETdgG7Nr8vLTi184=";
		};
		xmladasrc = fetchgit {
			url = "https://github.com/AdaCore/xmlada.git";
			rev = "refs/tags/xmlada-21.0.0";
			sha256 = "sha256-/KvMMLo1l1SEksFM4dGtobqFi2o67VGQtKGkyfaUdAM=";
		};
		gprconfig_kbsrc = fetchgit {
			url = "https://github.com/AdaCore/gprconfig_kb.git";
			rev = "refs/tags/v21.0.0";
			sha256 = "sha256-7/ZbFOtMQzrajnFNl7lfgMTEcIsSikloh/VG0Jr7FYc=";
		};
		adaenv = gcc10Stdenv.override { name="adaenv"; cc = gnat10; };

		gprbuildboot = 
			adaenv.mkDerivation {
				name = "gprbuildboot";
				srcs = [ 
					gprbuildsrc
					xmladasrc
					gprconfig_kbsrc
				];
				sourceRoot = "gprbuild";
				patchPhase = "
					patchShebangs ./bootstrap.sh
				";
				dontConfigure = true;
				dontBuild = true;
				installPhase = ''
					./bootstrap.sh \
					--with-xmlada=../xmlada \
					--with-kb=../gprconfig_kb \
					--prefix=$prefix 
				'';
			};

		in rec {
		packages.x86_64-linux.gprbuildboot = gprbuildboot;

		packages.x86_64-linux.xmlada = 
			adaenv.mkDerivation {
				name = "xmlada";
				buildInputs = [ 
					gprbuildboot
				];
				src = xmladasrc;
				# disable-shared needed to avoid crti.o linking error. Why?
				configurePhase = ''
					./configure --prefix=$prefix
				'';
				buildPhase = ''
					make all
				'';
				installPhase = ''
					make install
				'';
			};
		packages.x86_64-linux.gprbuild =
			adaenv.mkDerivation {
				name = "gprbuild";
				buildInputs = [
					packages.x86_64-linux.xmlada
					gprbuildboot
				];
				srcs = [ 
					gprbuildsrc
					xmladasrc
					gprconfig_kbsrc
				];
				sourceRoot = "gprbuild";
				GPR_PROJECT_PATH=packages.x86_64-linux.xmlada + "/share/gpr";
				configurePhase = ''
					make prefix=$prefix ENABLE_SHARED=no setup
				'';
				buildPhase = ''
					make all
				'';
			};


		packages.x86_64-linux.spark2014 = 
			with import nixpkgs { system = "x86_64-linux"; };
			adaenv.mkDerivation rec {
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
						deepClone = true;
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

		defaultPackage.x86_64-linux = packages.x86_64-linux.gprbuild;
	};
}

