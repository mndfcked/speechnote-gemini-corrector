self: { config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.speechnote-gemini-corrector;
in
{
  options.services.speechnote-gemini-corrector = {
    enable = mkEnableOption "Enable the SpeechNote Gemini corrector service";

    apiKeyFile = mkOption {
      type = types.str;
      default = "";
      description = "Path to the file containing your Gemini API key";
      example = "/path/to/gemini-api-key";
    };

    geminiModel = mkOption {
      type = types.str;
      default = "gemini-2.0-flash-lite";
      description = "The Gemini model to use for text correction";
      example = "gemini-2.0-pro";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.speechnote-gemini-corrector = {
      Unit = {
        Description = "SpeechNote Gemini Corrector";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.python3}/bin/python ${self.packages.${pkgs.system}.speechnote-gemini-corrector}/share/speechnote-gemini-corrector/gemini-corrector.py";
        Restart = "on-failure";
        Environment = [
          "GEMINI_API_KEY_FILE=${cfg.apiKeyFile}"
          "GEMINI_MODEL=${cfg.geminiModel}"
        ];
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    home.packages = with pkgs; [
      wl-clipboard
      python3
      python3Packages.dbus-python
      python3Packages.pygobject3
      python3Packages.notify2
      python3Packages.google-generativeai
    ];
  };
}