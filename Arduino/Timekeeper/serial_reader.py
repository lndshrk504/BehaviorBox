import serial
import time

# Parameters: replace 'COM3' and baudrate with the correct values for your setup
serial_port = 'COM3'
baudrate = 115200

# Generate a filename based on the current date and time
current_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
output_file = f'serial_output_{current_datetime}.txt'

# Configure and open the serial port
ser = serial.Serial(serial_port, baudrate, timeout=1)

try:
    with open(output_file, 'w') as f:
        while True:
            if ser.in_waiting > 0:
                # Read line from serial port
                line = ser.readline()
                # Decode byte to string and strip any line endings
                line = line.decode('utf-8').strip()
                # Write the string to a file with a newline character
                f.write(line + '\n')
                # Print to console for immediate feedback
                print(line)
            time.sleep(0.1)  # Sleep a bit to avoid overwhelming the CPU
except KeyboardInterrupt:
    print("Recording stopped.")
finally:
    ser.close()