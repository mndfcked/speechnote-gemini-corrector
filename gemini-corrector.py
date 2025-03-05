#!/usr/bin/env python3

# Import and setup D-Bus main loop before any other imports
from dbus.mainloop.glib import DBusGMainLoop

DBusGMainLoop(set_as_default=True)

import dbus
import dbus.service
import dbus.connection
import subprocess
import os
import signal
from google import genai
from gi.repository import GLib
import notify2

# D-Bus details
BUS_NAME = "net.mkiol.SpeechNote"
OBJECT_PATH = "/net/mkiol/SpeechNote"
INTERFACE = "net.mkiol.SpeechNote"

# Gemini API setup
GEMINI_API_KEY_FILE = os.environ.get("GEMINI_API_KEY_FILE")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.0-flash-lite")

# Read API key from file
try:
    with open(GEMINI_API_KEY_FILE, 'r') as f:
        GEMINI_API_KEY = f.read().strip()
except (FileNotFoundError, TypeError):
    GEMINI_API_KEY = None
    print(f"Error: Could not read API key from file: {GEMINI_API_KEY_FILE}")

client = genai.Client(api_key=GEMINI_API_KEY)
stt_text_in_clipboard = False  # Flag to track if clipboard has STT text
last_processed_text = ""  # Store the last processed text to avoid duplicates

# Initialize notification system
notify2.init("SpeechNote Gemini Corrector")


def get_clipboard():
    """Retrieve the current clipboard contents using wl-paste (Wayland)."""
    try:
        result = subprocess.run(
            ["wl-paste"], capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return "Error: Could not access clipboard"
    except FileNotFoundError:
        return "Error: wl-paste not found (install wl-clipboard)"


def set_clipboard(text):
    """Set the clipboard contents using wl-copy (Wayland)."""
    try:
        subprocess.run(["wl-copy"], input=text, text=True, check=True)
        print(f"Clipboard updated with: '{text}'")
        return True
    except subprocess.CalledProcessError:
        print("Error: Failed to set clipboard")
        return False
    except FileNotFoundError:
        print("Error: wl-copy not found (install wl-clipboard)")
        return False


def show_notification(title, message, urgency=notify2.URGENCY_NORMAL):
    """Display a system notification with the given title and message."""
    notification = notify2.Notification(title, message)
    notification.set_urgency(urgency)
    notification.show()


def fix_text_with_gemini(text):
    """Send text to Gemini to fix grammar and structure, keeping meaning intact."""
    prompt = f"""
    Fix the sentence structure, grammar, and writing of the following text, but preserve the original meaning as closely as possible. Do not rephrase or change the intent, just correct errors:
    '{text}'
    Return only the corrected text, nothing else.
    """
    try:
        show_notification("SpeechNote Gemini Corrector", "Sending text to Gemini for correction...")
        print("Sending text to Gemini for correction...")

        response = client.models.generate_content(
            model=GEMINI_MODEL, contents=prompt
        )
        corrected_text = response.text.strip()

        show_notification("SpeechNote Gemini Corrector", "Text corrected by Gemini!")
        return corrected_text
    except Exception as e:
        error_msg = f"Error calling Gemini API: {e}"
        print(error_msg)
        show_notification("SpeechNote Gemini Corrector Error", error_msg, notify2.URGENCY_CRITICAL)
        return text  # Return original text on failure


def process_clipboard():
    """Process the clipboard contents and send to Gemini for correction."""
    global stt_text_in_clipboard, last_processed_text
    print("Processing clipboard...")
    show_notification("SpeechNote Gemini Corrector", "Starting text correction process...")

    if stt_text_in_clipboard:  # Only proceed if flag is True
        # Get the clipboard contents
        clipboard = get_clipboard()
        print(f"Original clipboard contents: '{clipboard}'")

        # Check if this text has already been processed
        if clipboard == last_processed_text:
            print("Skipping Gemini API call because text has already been processed.")
            stt_text_in_clipboard = False  # Reset the flag
            return

        # Check for clipboard errors
        if clipboard and "Error" not in clipboard:
            # Correct the text using Gemini
            corrected_text = fix_text_with_gemini(clipboard)
            print(f"Corrected text from Gemini: '{corrected_text}'")

            # Set the corrected text to the clipboard
            if set_clipboard(corrected_text):
                show_notification(
                    "SpeechNote Gemini Corrector",
                    "Process completed! Text corrected and copied to clipboard.",
                    notify2.URGENCY_NORMAL,
                )
                # Update the last processed text
                last_processed_text = corrected_text
            else:
                show_notification(
                    "SpeechNote Gemini Corrector Error",
                    "Failed to update clipboard!",
                    notify2.URGENCY_CRITICAL,
                )
        else:
            error_msg = "Skipping Gemini API call due to clipboard error"
            print(error_msg)
            show_notification("SpeechNote Gemini Corrector Error", error_msg, notify2.URGENCY_CRITICAL)

        stt_text_in_clipboard = False  # Reset the flag
    else:
        print("Skipping Gemini API call because clipboard doesn't contain STT output.")


# D-Bus signal handlers
def on_task_state_changed(new_state):
    """Handle TaskStatePropertyChanged signal."""
    global stt_text_in_clipboard  # Access the global variable
    print(f"TaskState changed to: {new_state}")

    # Correcting text when the task state changes to 0 (idle)
    if new_state == 0:
        print("STT task completed (TaskState returned to 0)!")
        stt_text_in_clipboard = True  # Set the flag to True
        process_clipboard()


def on_invoke_action(action_name, argument):
    """Handle InvokeAction method call."""
    print(f"InvokeAction called with action: {action_name}, argument: {argument}")

    if action_name == "start-listening-clipboard":
        print("Start listening action received!")
        show_notification(
            "SpeechNote Gemini Corrector", "Speech recognition started. Will correct text when completed."
        )

    elif action_name == "stop-listening":
        print("Stop listening action received!")
        show_notification("SpeechNote Gemini Corrector", "Speech recognition stopped.")


def quit_handler(signum, frame):
    """Handle termination signals."""
    print(f"Received signal {signum}. Exiting...")
    show_notification(
        "SpeechNote Gemini Corrector", "Service stopped by system signal.", notify2.URGENCY_LOW
    )
    exit(0)


def main():
    if not GEMINI_API_KEY:
        show_notification(
            "SpeechNote Gemini Corrector Error", 
            f"Missing API key. Set GEMINI_API_KEY_FILE environment variable.",
            notify2.URGENCY_CRITICAL
        )
        return

    try:
        # Register signal handlers for termination signals
        signal.signal(signal.SIGTERM, quit_handler)
        signal.signal(signal.SIGINT, quit_handler)

        # Get the session bus
        bus = dbus.SessionBus()

        # Connect to the TaskStatePropertyChanged signal
        bus.add_signal_receiver(
            on_task_state_changed,
            signal_name="TaskStatePropertyChanged",
            dbus_interface=INTERFACE,
            bus_name=BUS_NAME,
            path=OBJECT_PATH,
        )

        # Connect to the InvokeAction method call
        bus.add_message_filter(
            lambda bus, message: (
                (
                    on_invoke_action(
                        message.get_args_list()[0], message.get_args_list()[1]
                    )
                    if (
                        message.get_type() == dbus.lowlevel.MESSAGE_TYPE_METHOD_CALL
                        and message.get_member() == "InvokeAction"
                        and message.get_interface() == INTERFACE
                        and message.get_path() == OBJECT_PATH
                    )
                    else None
                ),
                dbus.lowlevel.HANDLER_RESULT_NOT_YET_HANDLED,
            )[1]
        )

        # Notify that the application has started
        show_notification(
            "SpeechNote Gemini Corrector",
            "Service started. Monitoring SpeechNote events...",
            notify2.URGENCY_LOW,
        )
        print("SpeechNote Gemini Corrector service started. Monitoring SpeechNote events...")

        print("Starting GLib main loop...")
        # Start the main loop
        loop = GLib.MainLoop()
        loop.run()

    except Exception as e:
        error_msg = f"Error in main function: {e}"
        print(error_msg)
        show_notification("SpeechNote Gemini Corrector Error", error_msg, notify2.URGENCY_CRITICAL)


if __name__ == "__main__":
    main()