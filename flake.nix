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
      in
      {
        packages.default = self.packages.${system}.speechnote-gemini-corrector;
        
        packages.speechnote-gemini-corrector = pkgs.stdenv.mkDerivation {
          name = "speechnote-gemini-corrector";
          version = "0.1.0";
          src = ./.;
          
          installPhase = ''
            mkdir -p $out/share/speechnote-gemini-corrector
            cp gemini-corrector.py $out/share/speechnote-gemini-corrector/
          '';
        };
        
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python3
            python3Packages.dbus-python
            python3Packages.pygobject3
            python3Packages.notify2
            python3Packages.google-generativeai
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