#!/usr/bin/env bash
# debug-wrapper.sh - Wrapper to debug GObject Introspection issues

# Log the environment variables to a file for debugging
env > /tmp/speechnote-gemini-env.log

# Print GI typelib paths
echo "GI_TYPELIB_PATH: $GI_TYPELIB_PATH" >> /tmp/speechnote-gemini-debug.log
echo "XDG_DATA_DIRS: $XDG_DATA_DIRS" >> /tmp/speechnote-gemini-debug.log
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH" >> /tmp/speechnote-gemini-debug.log

# Find GLib typelib files in the Nix store
find /nix/store -name "GLib-2.0.typelib" | head -n 3 >> /tmp/speechnote-gemini-debug.log

# Now run the actual script
exec "$@"
