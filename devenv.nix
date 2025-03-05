{ pkgs, ... }: {
  # https://devenv.sh/languages/python/
  languages.python = {
    enable = true;
    venv.enable = true;
    venv.requirements = ''
      google-genai
    '';
  };

  packages = with pkgs.python3Packages; [
    pip
    dbus-python
    pygobject3
    notify2
    black
    mypy
    pylint
  ];
}
