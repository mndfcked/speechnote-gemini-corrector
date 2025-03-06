{
  description = "SpeechNote Gemini Corrector - Grammar correction for SpeechNote using Gemini AI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, home-manager, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Create a Python environment with all dependencies
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          dbus-python
          pygobject3
          notify2
          
          # For dependencies not in nixpkgs, we use pip
          (
            buildPythonPackage rec {
              pname = "google-genai";
              version = "1.4.0";
              format = "pyproject";
              
              src = fetchPypi {
                inherit pname version;
                sha256 = "sha256-aVn23g67PW3Qge6ZI0lFoozdoWVRrISy29k4uvBKTBQ="; 
              };
              
              propagatedBuildInputs = [
                setuptools
                wheel
                pip
                # Dependencies required by google-genai
                requests
                google-auth
                httpx
                pydantic
                websockets
                typing-extensions
              ];
              
              # Skip tests as they might require credentials
              doCheck = false;
            }
          )
        ]);
      in
      {
        packages.default = self.packages.${system}.speechnote-gemini-corrector;
        
        packages.speechnote-gemini-corrector = pkgs.stdenv.mkDerivation {
          name = "speechnote-gemini-corrector";
          version = "0.1.0";
          src = ./.;
          
          buildInputs = [
            pythonEnv
            pkgs.makeWrapper
          ];
          
          installPhase = ''
            mkdir -p $out/{bin,share/speechnote-gemini-corrector}
            cp gemini-corrector.py $out/share/speechnote-gemini-corrector/
            
            # Create a wrapper script that sets up the Python environment
            makeWrapper ${pythonEnv}/bin/python $out/bin/speechnote-gemini-corrector \
              --add-flags $out/share/speechnote-gemini-corrector/gemini-corrector.py \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.wl-clipboard ]} \
              --set PYTHONPATH ${pythonEnv}/${pythonEnv.sitePackages}
            
            # Make the wrapper executable
            chmod +x $out/bin/speechnote-gemini-corrector
          '';
        };
        
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            pythonEnv
            wl-clipboard
          ];
        };
      }
    ) // {
      homeManagerModules.default = import ./module.nix self;
      
      # For backwards compatibility
      homeManagerModule = self.homeManagerModules.default;
    };
}
