{
	description = "Compilers and tools for SPARK2014 Ada development";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/20.09";

	outputs = { self, nixpkgs }:
		with import nixpkgs {
			system = "x86_64-linux";
		};

	let

	python = python27;
	pythonPackages = python27Packages;

	# Customized environment supporting gprbuild search paths.

	base_env = gcc10Stdenv;

	mk_gpr_path = inputs :
		lib.strings.makeSearchPath "share/gpr" inputs
		+ ":" +
		lib.strings.makeSearchPath "lib/gnat" inputs;

	adaenv_func = include_gprbuild : let
		maybe_gpr = if include_gprbuild then [gprbuild] else [];
		core = (overrideCC base_env gnat10).override {
			name="adaenv" + (if include_gprbuild then "-boot" else "");
			initialPath = base_env.initialPath ++ maybe_gpr;
		};
		in
			core // { # use modified mkDerivation function
			mkDerivation = params :
			assert lib.asserts.assertMsg (params ? name)
			"Attribute 'name' of derivation must be specified!"; let
				new_params = params // {

				# Fix crti.o linker error
				LIBRARY_PATH = params.LIBRARY_PATH or "${adaenv.glibc}/lib";

				# Find installed gpr projects in nix store. Consult
				# GPR manual for search path order
				GPR_PROJECT_PATH = mk_gpr_path ((new_params.buildInputs or []) ++ maybe_gpr);

				};
			in core.mkDerivation new_params;
		};

	adaenv_boot = adaenv_func false; # does not include gprbuild by default
	adaenv = adaenv_func true; # does include gprbuild by default

	# xmlada library needed for gprbuild. Built with bootstrap.

	xmladasrc = fetchFromGitHub {
		owner = "AdaCore";
		repo = "xmlada";
		rev = "4aca7578264b3d42d9629a7437705a3b62c6fa04"; # version 20.2
		sha256 = "sha256-aBfhmnbzJxdqdItVM6dn29C5JYE8jMhpBYjYv+RQA40=";
	};

	xmlada = adaenv_boot.mkDerivation {
		name = "xmlada";
		version = "20.2";
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
		rev = "245ee13c5cd384dc3cea10a49a5e6a07042e49e1"; # version 20.2
		sha256 = "sha256-wAnDQXyg0vR3TfsKtfvYnDZ1CnX+1ZRRQi7XwOTckNo=";
	};

	gprconfig_kbsrc = fetchFromGitHub {
		owner = "AdaCore";
		repo = "gprconfig_kb";
		rev = "94abfa8bb8da6457ac0288907a817f691d00f74e"; # version 20.2
		sha256 = "sha256-S+iH0h50o6HdoSDf+8SQ5Fe3IOf/AGEe46fyfdnKsIk=";
	};

	gprbuild-bootstrap = adaenv_boot.mkDerivation {
		name = "gprbuild-bootstrap";
		version = "20.2";
		src = gprbuildsrc;
		patchPhase = "
			patchShebangs ./bootstrap.sh
		";
		dontConfigure = true;
		dontBuild = true;
		installPhase = ''
			./bootstrap.sh \
			--with-xmlada="${xmladasrc}" \
			--prefix=$prefix
		'';
	};

	gprbuild = adaenv_boot.mkDerivation {
		name = "gprbuild";
		version = "20.2";
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
		rev = "d71d4fce1438dd645c546892a8c8a6a5e65a856d"; # version 20.2
		sha256 = "sha256-yEGj9ku3o+BOH8BwA/SuLsLCr/CcWdEdzzdrtOsy1wg=";
	};

	gnatcoll-core = adaenv.mkDerivation {
		name = "gnatcoll-core";
		version = "20.2";
		buildInputs = [
			xmlada
		];
		src = gnatcoll-coresrc;
		configurePhase = ''
			make prefix=$prefix BUILD=PROD setup
		'';
	};

	gnatcoll-dbsrc = fetchFromGitHub {
		owner = "AdaCore";
		repo = "gnatcoll-db";
		rev = "b0b82d7859d7b6c4a9ade11f4dd78e46305d4716"; # version 20.2
		sha256 = "sha256-RVD1stH/0W6pgcRGqsZsMxwNgDF4nailM8uS0f51OFI=";
	};

	gnatcoll-db = { component, extra_inputs ? [] }:
		adaenv.mkDerivation {
			name = "gnatcoll-db-" + component;
			version = "20.2";

			buildInputs = [
				gprbuild
				gnatcoll-core
				xmlada
			] ++ extra_inputs;

			src = gnatcoll-dbsrc;

			COMPONENT = component;

			configurePhase = ''
				make -C $COMPONENT prefix=$prefix BUILD=PROD setup
			'';

			buildPhase = ''
				make -C $COMPONENT
			'';

			installPhase = ''
				make -C $COMPONENT install
			'';
		};

	gnatcoll-db-sql = gnatcoll-db { component = "sql"; };

	gnatcoll-db-sqlite = gnatcoll-db { component = "sqlite"; extra_inputs = [ gnatcoll-db-sql which ]; };

	gnatcoll-db-xref = gnatcoll-db { component = "xref"; extra_inputs = [ gnatcoll-bindings-iconv gnatcoll-db-sql gnatcoll-db-sqlite ]; };

	gnatcoll-db-db2ada = gnatcoll-db { component = "gnatcoll_db2ada"; extra_inputs = [ gnatcoll-db-sql gnatcoll-db-sqlite gnatcoll-db-xref ]; };

	gnatcoll-bindingssrc = fetchFromGitHub {
		owner = "AdaCore";
		repo = "gnatcoll-bindings";
		rev = "ad7e9cea450f8fb8005b2b35217863dfd2edb79c"; # version 20.2
		sha256 = "sha256-Pk1DtHPECTx9SxlCHN4cszUJqfc56fhPNe5izW10P/Q=";
	};

	gnatcoll-bindings = { component, extra_inputs ? [] }:
		adaenv.mkDerivation {
			name = "gnatcoll-bindings-" + component;
			version = "20.2";

			buildInputs = [
				gnatcoll-core
				gprbuild
				python
				xmlada
			] ++ extra_inputs;

			src = gnatcoll-bindingssrc;

			COMPONENT = component;

			patchPhase = ''
				patchShebangs ./ + $COMPONENT + /setup.py
			'';

			buildPhase = ''
				cd $COMPONENT && ./setup.py build --prefix=$prefix
			'';

			installPhase = ''
				./setup.py install --prefix=$prefix
			'';
		};

	gnatcoll-bindings-iconv = gnatcoll-bindings { component = "iconv"; };

	gnatcoll-bindings-gmp = gnatcoll-bindings { component = "gmp"; extra_inputs = [ gmp ]; };

	gnatcoll-bindings-python = gnatcoll-bindings { component = "python"; };

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
		version = "20.2";
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

	# ASIS tools like gnattest, gnatcheck, etc.
	aunitsrc = fetchFromGitHub {
		owner = "AdaCore";
		repo = "aunit";
		rev = "5a4c3255af756177aead3ff89b2278a1a47009e4"; # tag 20.2
		sha256 = "sha256-45hevx+oUiZLKER3cZF4FHJT5IFOKMKsY7L8u8rDa+E=";
	};

	aunit = adaenv.mkDerivation {
		name = "AUnit";
		version = "20.2";
		src = aunitsrc;
		installPhase = ''
			make INSTALL=$prefix install
		'';
	};

	gnat_utilsrc = fetchFromGitHub {
		owner = "simonjwright";
		repo = "gnat_util";
		rev = "7e5af8f4365b49cd39b1e7de5fd3c6eb71b989e2";
		sha256 = "sha256-Pz2B/W3FRN6zwOk6MXNuHKDa3539/wshZuFDjtrdZ18="; # gcc 10.1.0
	};

	gnat_util = adaenv.mkDerivation {
		name = "gnat_util";
		version = "10.1.0";
		srcs = [
			gnat_utilsrc
			gnatsrc # list here to get local uncompressed copy
		];
		sourceRoot = "source";
		GCC_SRC_BASE="gcc-10.2.0";
		installPhase = ''
			make prefix=$prefix install
		'';
	};

	asis = adaenv.mkDerivation {
		name = "ASIS";
		version = "gcc-10.1.0";
		src = fetchFromGitHub {
			owner = "simonjwright";
			repo = "asis";
			rev = "75eabc75aa5f7f1559524153f209601574f32b5c"; # gcc-10.1 tag
			sha256 = "sha256-26kmPF8uksCOHc5yqJZ8DW7rS56fClff5cIMj0x5+MI=";
			# The asis distribution must include source code that matches the
			# version of gcc used.
		};
		buildInputs = [
			xmlada
			aunit
			gnat_util
			gnatcoll-core
		];
		postUnpack = ''
			make -C source xsetup-snames
			cp -nr source/gnat/* source/asis/
		'';
		buildPhase = ''
			make all tools
		'';
		installPhase = ''
			make prefix=$prefix install install-tools
		'';
	};

	alire = adaenv.mkDerivation rec {
		name = "alire";
		# v1.0.0 failed to fetch submodules, so using current HEAD
		version = "1.1.0-dev+0f603c29";
		src = fetchFromGitHub {
			owner = "alire-project";
			repo = "alire";
			rev = "c63615df9bed6212881f61d769ab189b3f425a8b";
			sha256 = "sha256-bs1myX6Qgsdp/RU9FvOaDJ6nB9gsa0oDsNjwYctP/Dw=";
			fetchSubmodules = true;
		};

		buildInputs = [ gprbuild git ];

		buildPhase = ''
			gprbuild -j0 -P alr_env
		'';

		installPhase = ''
			install -D bin/alr $out/bin/alr
		'';

		};

	gtkada_src = fetchFromGitHub {
		owner = "AdaCore";
		repo = "gtkada";
		rev = "4f311f1848c2a7b45c5c97e00c5b3b01ab14797b"; # version 20.02
		sha256 = "sha256-NElipEicNldbswvZFf5ye6wv8OOLWAsVyO0wffzLgFY=";
	};

	gtkada = adaenv.mkDerivation rec {
		name = "gtkada";
		version = "20.02";
		src = gtkada_src;

		buildInputs = [ gtk3 pkg-config ];
	};

	langkit_src = fetchFromGitHub {
		owner = "AdaCore";
		repo = "langkit";
		rev = "d92444bda33a5d83e13a8114c5e7b7626cc15fdd"; # version 20.02
		sha256 = "sha256-d75QTilNqchhd5uFXZRzToXpCQ+dt1HJFbf2tDK8G8E=";
	};

	langkit =  python.pkgs.buildPythonPackage rec {
		pname = "langkit";
		version = "0.1.dev0";

		src = langkit_src;

		# TODO: Use REQUIREMENTS.txt from repo
		buildInputs = [
			python
			pythonPackages.docutils
			pythonPackages.enum
			pythonPackages.enum34
			pythonPackages.funcy
			pythonPackages.Mako
			pythonPackages.pip
			pythonPackages.pyyaml
			pythonPackages.setuptools
		];
	};

	libadalang_src = fetchFromGitHub {
		owner = "AdaCore";
		repo = "libadalang";
		rev = "88e30708e1a41d411a33bd239497346e03f8d8a6"; # version 20.02
		sha256 = "sha256-ZkRBNhjz7B2HSTyM2gjWT7+uRoWZsgUaBi0bTVmaQKo=";
	};

	libadalang = adaenv.mkDerivation rec {
		name = "libadalang";
		version = "20.02";
		src = libadalang_src;

		# TODO: Do not copy from requirements.txt
		buildInputs = [
			gmp
			gnatcoll-core
			gnatcoll-bindings-iconv
			gnatcoll-bindings-gmp
			langkit
			python
			pythonPackages.docutils
			pythonPackages.enum34
			pythonPackages.funcy
			pythonPackages.Mako
			pythonPackages.pip
			pythonPackages.pytestrunner
			pythonPackages.pyyaml
			pythonPackages.setuptools
			pythonFull
			xmlada
		];

		dontStrip = true;
		enableDebugging = true;

		# https://github.com/AdaCore/ada_language_server/issues/217
		buildPhase = ''
			python ada/manage.py --library-types=static,static-pic,relocatable generate
			python ada/manage.py --library-types=static,static-pic,relocatable build
		'';

		installPhase = ''
			python ada/manage.py --library-types=static,static-pic,relocatable install $prefix
		'';
	};

	libadalang_tools_src = fetchFromGitHub {
		owner = "AdaCore";
		repo = "libadalang-tools";
		rev = "b377f3a62a0ed2c712076fd774858fb3e49f5a86"; # version 20.02
		sha256 = "sha256-8o7h3Z9t8YaYMfy87mPWr9FuylGNxzrPrn0chb0he2s=";
	};

	libadalang_tools = adaenv.mkDerivation rec {
		name = "libadalang_tools";
		version = "20.02";
		src = libadalang_tools_src;

		buildInputs = [
			binutils
			gmp
			gnatcoll-bindings-gmp
			gnatcoll-bindings-iconv
			gnatcoll-core
			gprbuild
			langkit
			libadalang
			which
			xmlada
		];

		# TODO: gprbuild at some stage seems to look for in binaries a section
		# called GPR.linker_options and append those to the linker. Without
		# specifying the following libraries, linkage will fail with missing
		# symbols. Maybe related:
		# https://comp.lang.ada.narkive.com/bg0fcXsk/dynamic-link-library
		patchPhase = ''
			sed -i s/-j\$\(PROCESSORS\)/-j\$\(PROCESSORS\)\ -largs\ -lgnarl\ -lgnat\ -lutil\ /g Makefile
		'';

		installPhase = ''
			make install-strip DESTDIR=$prefix
		'';
	};

	ada_language_server_src = fetchFromGitHub {
		owner = "AdaCore";
		repo = "ada_language_server";
		rev = "fe1864d1c84b57b183084f045ee49225914babf8"; # version 20.02
		sha256 = "sha256-W5/OvR+M/iQ79GC8Z8igT1wAFZcz9WnMfvI7VgU15zI=";
	};

	ada_language_server = adaenv.mkDerivation rec {
		name = "ada_language_server";
		version = "20.02";
		src = ada_language_server_src;

		buildInputs = [ gprbuild gnatcoll-core xmlada libadalang
			gmp
			gnatcoll-bindings-gmp
			gnatcoll-bindings-iconv
		];

		# https://www.gnu.org/prep/standards/html_node/DESTDIR.html
		pathPhase = ''
			sed -i s/DESTDIR=//g Makefile
		'';

		buildPhase = ''
			make LIBRARY_TYPE=static DESTDIR=$prefix
		'';

		installPhase = ''
			make LIBRARY_TYPE=static DESTDIR=$prefix install
		'';
	};

	gps_src = fetchFromGitHub {
		owner = "AdaCore";
		repo = "gps";
		rev = "ba40aed530e31f70d14b437b94b529a4d1f8253e"; # version 20.02
		sha256 = "sha256-nxAWIvYrldnRHm4ukNIstBSPvDyQaH9PXu6VDWBTj1s=";
	};

	gps = adaenv.mkDerivation rec {
		name = "gps";
		version = "20.02";

		inherit ada_language_server_src libadalang_tools_src;

		src = gps_src;

		buildInputs = [
			gnatcoll-bindings-gmp
			gnatcoll-bindings-iconv
			gnatcoll-bindings-python
			gnatcoll-core
			gnatcoll-db-db2ada
			gnatcoll-db-sql
			gnatcoll-db-sqlite
			gnatcoll-db-xref
			gtk3
			gtkada
			libadalang
			llvmPackages.libclang
			pkg-config
			python
			pythonPackages.pygobject3
			xmlada
		];

		patchPhase = ''
			sed -i s/GPRBUILD_FLAGS=/GPRBUILD_FLAGS=-j0/g gnatstudio/Makefile
		'';

		configurePhase = ''
			cp -R $ada_language_server_src ./ada_language_server
			cp -R $libadalang_tools_src    ./laltools
			chmod -R u+w ./ada_language_server
			chmod -R u+w ./laltools
			./configure --prefix=$prefix
		'';
	};

	in

	# HERE BEGINS THE THINGS THAT THIS FLAKE PROVIDES:
	{
		# Derivations (create an environment with `nix shell`)
		inherit xmlada gnatcoll-core asis gnat_util aunit gps;
		gpr = gprbuild;
		gnat = adaenv.cc;
		spark = spark2014;
		alr = alire;

		# Notes on nix shell and nix develop:
		# "nix develop" will open a shell environment that simulates the build environment
		# for the specified derivation, with default being devShell if it is defined, and
		# defaultPackage if it is not.  If the the derivation has a shellHook, it will be
		# run.  However, buildEnv is not allowed to have a shellHook for some reason.  The
		# derivation can be a buildable package (including buildEnv) or not like mkShell.
		#
		# "nix shell" will open a shell environment with the specified *packages* installed
		# on the PATH. The default is defaultPackage.  devShell is not used. shellHooks will
		# not be run. A mkShell invocation cannot be installed, so it cannot be used with
		# nix shell.

		adaspark = buildEnv {
			name = "adaspark";
			paths = [
				self.gnat
				gnat10.cc # need the original compiler on the path for gprconfig to work
				self.gpr
				self.spark
				self.asis
				self.alr
				self.gps
			];
		};

		packages.x86_64-linux = {
			inherit (self) xmlada gnatcoll-core gnat gpr spark adaspark gnat_util aunit asis gps;
		};
		defaultPackage.x86_64-linux = self.packages.x86_64-linux.adaspark;
		devShell.x86_64-linux = mkShell {
			buildInputs = [self.adaspark];
			LIBRARY_PATH=self.gpr.LIBRARY_PATH; # pull out any LIBRARY_PATH from a adaenv derivation
		};

		# End derivations

		# Put the adaenv function in the flake so other users can download it and use its
		# mkDerivation function and other features.
		inherit adaenv fetchFromGitHub fetchgit fetchtarball;
	};
}

