{
	description = "Alire project manager for Ada and SPARK development";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/21.11";

	outputs = { self, nixpkgs }: 
		with import nixpkgs { 
			system = "x86_64-linux"; 
		}; 

	let

	alire = stdenv.mkDerivation rec {
		pname = "alire";
		version = "v1.2.0";
		src = fetchFromGitHub {
			owner = "alire-project";
			repo = "alire";
			rev = "42fbc58dec7df542c42c682cd44b47a37756831c";
			sha256 = "sha256-bXe4/YegE3agc9BwbkqFzJDbYvC0if8DPMy1vvn8ecA=";
			fetchSubmodules = true;
		};

		buildInputs = [ gprbuild gnat ];

		buildPhase = ''
			gprbuild -j0 -P alr_env
		'';

		installPhase = ''
			install -D bin/alr $out/bin/alr
		'';

		};

	in 

	{
		packages.x86_64-linux = {
			inherit alire;
		};
		defaultPackage.x86_64-linux = alire;
	};
}

