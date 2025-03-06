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
            pkgs.makeWrapper
            pkgs.wrapGAppsHook
          ];
          
          buildInputs = [
            pythonEnv
            pkgs.glib
            pkgs.gtk3
            pkgs.gobject-introspection
          ];
          
          # Create a debug wrapper script
          preInstall = ''
            mkdir -p $out/libexec
            cat > $out/libexec/debug-wrapper.sh << 'EOF'
#!/usr/bin/env bash
# Log environment for debugging
env > /tmp/speechnote-gemini-env.log 
echo "Running with arguments: $@" >> /tmp/speechnote-gemini-debug.log
exec "$@"
EOF
            chmod +x $out/libexec/debug-wrapper.sh
          '';
          
          installPhase = ''
            mkdir -p $out/{bin,share/speechnote-gemini-corrector}
            cp gemini-corrector.py $out/share/speechnote-gemini-corrector/
            
            # Create a version that explicitly sets all GObject Introspection environment variables
            cat > $out/bin/speechnote-gemini-corrector << EOF
#!/usr/bin/env bash
export GI_TYPELIB_PATH="${pkgs.glib}/lib/girepository-1.0:${pkgs.gtk3}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0"
export XDG_DATA_DIRS="${pkgs.gtk3}/share:\$XDG_DATA_DIRS"
export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.glib pkgs.gtk3 ]}"
exec ${pythonEnv}/bin/python ${placeholder "out"}/share/speechnote-gemini-corrector/gemini-corrector.py "\$@"
EOF
            chmod +x $out/bin/speechnote-gemini-corrector
            
            # For debugging, create a secondary version that uses our debug wrapper
            cat > $out/bin/speechnote-gemini-corrector-debug << EOF
#!/usr/bin/env bash
export GI_TYPELIB_PATH="${pkgs.glib}/lib/girepository-1.0:${pkgs.gtk3}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0"
export XDG_DATA_DIRS="${pkgs.gtk3}/share:\$XDG_DATA_DIRS"
export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.glib pkgs.gtk3 ]}"
exec ${placeholder "out"}/libexec/debug-wrapper.sh ${pythonEnv}/bin/python ${placeholder "out"}/share/speechnote-gemini-corrector/gemini-corrector.py "\$@"
EOF
            chmod +x $out/bin/speechnote-gemini-corrector-debug
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
            export GI_TYPELIB_PATH="${pkgs.glib}/lib/girepository-1.0:${pkgs.gtk3}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0"
            export XDG_DATA_DIRS="${pkgs.gtk3}/share:$XDG_DATA_DIRS"
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.glib pkgs.gtk3 ]}"
            
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
