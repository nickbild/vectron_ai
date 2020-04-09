import glob
import sys


vectors = []
labels = []


def load_training_data():
    files = glob.glob("train/*/image_*.txt")
    for file in files:
        label = file.split("/")[-2]
        with open(file, "r") as f:
            vector = []
            for line in f:
                line = int(line.strip())
                vector.append(line)
            vectors.append(vector)
            labels.append(label)
    return


def load_single_image(file):
    vector = []

    with open(file, "r") as f:
        for line in f:
            line = int(line.strip())
            vector.append(line)

    return vector


def calculate_distances_to_new_point(new_vector):
    results = {}

    for i in range(len(vectors)):
        distance = 0
        for j in range(len(vectors[i])):
            distance += abs(vectors[i][j] - new_vector[j])
        if distance in results and results[distance] != labels[i]:
            print("Warning: duplicate distance found and label not same!")
        results[distance] = labels[i]

    return results


load_training_data()

v = load_single_image(sys.argv[1])
results = calculate_distances_to_new_point(v)

for r in sorted(results.keys()):
    print("{}: {}".format(r, results[r]))
