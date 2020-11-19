{
	description = "A very basic flake";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/20.09";

	outputs = { self, nixpkgs }: {

		packages.x86_64-linux.gprbuild = 
			with import nixpkgs { 
				system = "x86_64-linux"; 
				overlays =[
					# (self: super: { gcc = super.gnat10; }) # ? doesn't work?
				];
			};
			(overrideCC gcc10Stdenv gnat10).mkDerivation {
				name = "gprbuild";
				buildInputs = [ 
					which
				];
				srcs = [ 
					(fetchgit {
						url = "https://github.com/AdaCore/gprbuild.git";
						rev = "refs/tags/v21.0.0";
						sha256 = "sha256-0vqwUVtuiAh73ySfIwmok3wG2Y+ETdgG7Nr8vLTi184=";
					})
					(fetchgit {
						url = "https://github.com/AdaCore/xmlada.git";
						rev = "refs/tags/xmlada-21.0.0";
						sha256 = "sha256-/KvMMLo1l1SEksFM4dGtobqFi2o67VGQtKGkyfaUdAM=";
					})
					(fetchgit {
						url = "https://github.com/AdaCore/gprconfig_kb.git";
						rev = "refs/tags/v21.0.0";
						sha256 = "sha256-7/ZbFOtMQzrajnFNl7lfgMTEcIsSikloh/VG0Jr7FYc=";
					})
				];
				sourceRoot = "gprbuild";
				patchPhase = "
					patchShebangs ./bootstrap.sh
				";
				configurePhase = ''
					./bootstrap.sh \
					--with-xmlada=../xmlada \
					--with-kb=../gprconfig_kb \
					--prefix=$prefix \
					&& make prefix=$prefix setup
				'';
				buildPhase = ''
					cd ..
					export PATH=$out/bin/:$PATH
					chmod -R +w xmlada
					cd xmlada
					./configure --prefix=$prefix
					make all install
					cd ../gprbuild
					make all
				'';

			};

				

		packages.x86_64-linux.spark2014 = 
			with import nixpkgs { system = "x86_64-linux"; };
			stdenv.mkDerivation rec {
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
					gnat10
				];
				sparksrc = fetchgit {
						url = "https://github.com/AdaCore/spark2014.git";
						#ref = "refs/heads/fsf";
						rev = "f4f0bcee37975657cd858e2d523593ce8cad61d8";
						deepClone = true;
						sha256 ="sha256-C/R1RCc/TIJXudTcPk5ArbBSPv5/65lPGQWXz6/vqhk";
				};
				gnatsrc = gnat10.cc.src;
				srcs = [
					sparksrc
					gnatsrc
				];
				sourceRoot = "spark2014-f4f0bce";
				configurePhase = "ln -sf ../../gcc-10.2.0 gnat2why/gnat_src && make setup";
			};

		defaultPackage.x86_64-linux = self.packages.x86_64-linux.gprbuild;
	};
}

