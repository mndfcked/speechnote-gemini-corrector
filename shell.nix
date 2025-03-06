# shell.nix - Useful for development without using flakes
{ pkgs ? import <nixpkgs> {} }:

let
  # Python with our dependencies
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    dbus-python
    pygobject3
    notify2
    pip # For installing packages not in nixpkgs
  ]);
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    pythonEnv
    wl-clipboard
  ];
  
  # Set up environment variables for development
  shellHook = ''
    # Create a Python virtual environment if it doesn't exist
    if [ ! -d .venv ]; then
      ${pythonEnv}/bin/python -m venv .venv
    fi
    
    # Activate the virtual environment
    source .venv/bin/activate
    
    # Install google-genai from PyPI
    pip install google-genai
    
    # Let the developer know what to do next
    echo "Development environment activated!"
    echo "Run the script with: python ./gemini-corrector.py"
    echo "Set GEMINI_API_KEY_FILE to the path of your API key file"
  '';
}
