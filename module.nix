self: { config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.speechnote-gemini-corrector;
  
  # Define GI Typelib paths
  giTypeLibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0" [
    pkgs.glib
    pkgs.gtk3  # May be needed for notifications
  ];
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
        # Note: Using 'simple' type rather than 'dbus' since your script 
        # listens to D-Bus but isn't a D-Bus service itself
        Type = "simple";
        ExecStart = "${self.packages.${pkgs.system}.speechnote-gemini-corrector}/bin/speechnote-gemini-corrector";
        Restart = "on-failure";
        Environment = [
          "GEMINI_API_KEY_FILE=${cfg.apiKeyFile}"
          "GEMINI_MODEL=${cfg.geminiModel}"
          "GI_TYPELIB_PATH=${giTypeLibPath}"
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
      # Add needed libraries for GObject Introspection
      glib
      gtk3
    ];
  };
}
