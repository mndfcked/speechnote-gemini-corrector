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
              pyproject = true;

              src = pkgs.fetchFromGitHub {
                owner = "googleapis";
                repo = "python-genai";
                tag = "v${version}";
                hash = "sha256-aVn23g67PW3Qge6ZI0lFoozdoWVRrISy29k4uvBKTBQ=";
              };

              build-system = [ setuptools ];

              dependencies = [
                google-auth
                httpx
                pydantic
                requests
                typing-extensions
                websockets
              ];

              pythonImportsCheck = [ "google.genai" ];

              nativeCheckInputs = [
                pytestCheckHook
              ];

              # ValueError: GOOGLE_GENAI_REPLAYS_DIRECTORY environment variable is not set
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
          
          nativeBuildInputs = [
            pkgs.wrapGAppsHook
            pkgs.makeWrapper
          ];
          
          buildInputs = [
            pythonEnv
            pkgs.glib
            pkgs.gtk3
            pkgs.gobject-introspection
          ];
          
          # This ensures Python's path is properly set up when wrapGAppsHook runs
          dontWrapGApps = true;
          
          installPhase = ''
            mkdir -p $out/{bin,share/speechnote-gemini-corrector}
            cp gemini-corrector.py $out/share/speechnote-gemini-corrector/
            
            # First, create the basic wrapper with Python path
            makeWrapper ${pythonEnv}/bin/python $out/bin/speechnote-gemini-corrector \
              --add-flags "$out/share/speechnote-gemini-corrector/gemini-corrector.py" \
              --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.wl-clipboard ]}" \
              --set PYTHONPATH "${pythonEnv}/${pythonEnv.sitePackages}"
            
            # Then use wrapGAppsHook to set up all GLib/GTK environment variables
            wrapGApp $out/bin/speechnote-gemini-corrector
          '';
        };
        
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            pythonEnv
            wl-clipboard
            glib
            gtk3
            gobject-introspection
          ];
          
          shellHook = ''
            # Setup a development environment with GObject Introspection support
            export XDG_DATA_DIRS="$XDG_DATA_DIRS:${pkgs.gtk3}/share"
            export GI_TYPELIB_PATH="${pkgs.glib}/lib/girepository-1.0:${pkgs.gtk3}/lib/girepository-1.0"
            
            echo "Development environment activated with GObject Introspection support"
            echo "Run the script with: python ./gemini-corrector.py"
          '';
        };
      }
    ) // {
      homeManagerModules.default = import ./module.nix self;
      
      # For backwards compatibility
      homeManagerModule = self.homeManagerModules.default;
    };
}
