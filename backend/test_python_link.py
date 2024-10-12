import sys

def process_data(input_string):
  # Replace this with your actual logic
  return ["emoji", "are", "cool"]

while True:
  # Read the string from the standard input
  input_string = sys.stdin.readline().strip()

  # Process the data
  output_array = process_data(input_string)

  # Send the array back as a comma-separated string
  output_string = ",".join(output_array)
  print(output_string)
  sys.stdout.flush()
