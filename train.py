import random


inputs = []
hidden_layer_nodes = 8
output_layer_nodes = 4
weights1 = []
biases1 = []
weights2 = []
biases2 = []


with open('train/up/image_0.txt', 'r') as f:
    for pixel in f:
        pixel = int(pixel.strip())
        inputs.append(pixel)

print(inputs)

###
# Initialize network.
###

# Weights1 (input -> hidden).
for input_node in range(0, len(inputs)):
    weights1.append([])
    for hl_node in range(0, hidden_layer_nodes):
        weights1[input_node].append(random.randrange(0, 255))

# Biases1 (hidden layer).
for hl_node in range(0, hidden_layer_nodes):
    biases1.append(1)

#Weights2 (hidden -> output).
for hl_node in range(0, hidden_layer_nodes):
    weights2.append([])
    for out_node in range(0, output_layer_nodes):
        weights2[hl_node].append(random.randrange(0,255))

# Biases2 (output layer).
for out_node in range(0, output_layer_nodes):
    biases2.append(1)

print(weights1)
print(biases1)
print(weights2)
print(biases2)

