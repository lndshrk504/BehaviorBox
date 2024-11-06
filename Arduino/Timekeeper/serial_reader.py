# Platform-Specific Considerations:
# - Windows: Use serial port names like "COM3", "COM4", etc.
# - Linux: Use serial port paths like "/dev/ttyUSB0", "/dev/ttyS0".
#   Ensure your user has the appropriate permissions, potentially needing to be part of the 'dialout' group:
#   sudo usermod -aG dialout $USER
#   Remember to log out and back in after making this change.
#
# Required Module:
# - Ensure 'pyserial' is installed: pip install pyserial
#
# UTF-8 Decoding:
# - Handle potential decoding issues by using: line.decode('utf-8', errors='ignore') if necessary.

# USAGE:
# python serial_reader.py <serial_port>
# press Enter, type stop, and press Enter to terminate
# or press Ctrl+C

import argparse
import serial
import time
from datetime import datetime
import threading

def listen_for_stop(logging_active):
    # Listener for user input to stop logging
    input("Press Enter and type 'stop' to stop logging...\n")
    while True:
        user_input = input()
        if user_input.strip().lower() == 'stop':
            logging_active[0] = False
            print("Logging will stop shortly.")
            break

def main():
    # Set up argument parsing
    parser = argparse.ArgumentParser(description='Read from a serial port and log data.')
    parser.add_argument('serial_port', type=str, help='The serial port to connect to (e.g., COM3, /dev/ttyUSB0)')
    parser.add_argument('--baudrate', type=int, default=115200, help='Baudrate for the serial connection, default is 115200')
    
    args = parser.parse_args()

    # Use the serial port from command-line arguments
    serial_port = args.serial_port
    baudrate = args.baudrate

    # Generate a filename based on the current date and time
    current_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_file = f'serial_output_{current_datetime}.txt'

    # Configure and open the serial port safely
    try:
        ser = serial.Serial(serial_port, baudrate, timeout=1)
    except serial.SerialException as e:
        print(f"Error opening serial port {serial_port}: {e}")
        sys.exit(1)

    # Use a list to allow the thread to modify the value
    logging_active = [True]

    # Start a new thread for user input listening
    stop_thread = threading.Thread(target=listen_for_stop, args=(logging_active,))
    stop_thread.daemon = True  # Use daemon thread to exit when the main program exits
    stop_thread.start()

    try:
        with open(output_file, 'w') as f:
            while logging_active[0]:
                if ser.in_waiting > 0:
                    # Read line from serial port
                    line = ser.readline()
                    # Decode byte to string and strip any line endings
                    line = line.decode('utf-8', errors='ignore').strip()
                    # Write the string to a file with a newline character
                    f.write(line + '\n')
                    # Print to console for immediate feedback
                    print(line)
                time.sleep(0.1)  # Sleep a bit to avoid overwhelming the CPU
    except KeyboardInterrupt:
        print("Recording stopped by user.")
    finally:
        ser.close()
        stop_thread.join()  # Ensure the stop thread finishes

if __name__ == '__main__':
    main()
