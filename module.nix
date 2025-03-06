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

    debugMode = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debugging mode with environment logging";
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
        # Use the debug version when debug mode is enabled
        ExecStart = if cfg.debugMode 
          then "${self.packages.${pkgs.system}.speechnote-gemini-corrector}/bin/speechnote-gemini-corrector-debug"
          else "${self.packages.${pkgs.system}.speechnote-gemini-corrector}/bin/speechnote-gemini-corrector";
        Restart = "on-failure";
        # Set all environment variables explicitly in the service
        Environment = [
          "GEMINI_API_KEY_FILE=${cfg.apiKeyFile}"
          "GEMINI_MODEL=${cfg.geminiModel}"
          "GI_TYPELIB_PATH=${pkgs.glib}/lib/girepository-1.0:${pkgs.gtk3}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0"
          "XDG_DATA_DIRS=${pkgs.gtk3}/share"
          "LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ pkgs.glib pkgs.gtk3 ]}"
        ];
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    home.packages = with pkgs; [
      # Make the corrector script available in PATH
      self.packages.${pkgs.system}.speechnote-gemini-corrector
      # Dependencies for GObject Introspection
      glib
      gtk3
      gobject-introspection
    ];
  };
}
