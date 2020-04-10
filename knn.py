import glob
import sys
import operator


vectors = []
labels = []


def threshold(v):
    if v < 10:
        v = 0
    elif v < 20:
        v = 1
    elif v < 30:
        v = 2
    elif v < 40:
        v = 3
    elif v < 50:
        v = 4
    else:
        v = 5

    return v


def load_training_data():
    files = glob.glob("train/*/image_*.txt")
    for file in files:
        label = file.split("/")[-2]
        with open(file, "r") as f:
            vector = []
            for line in f:
                line = int(line.strip())
                line = threshold(line)
                vector.append(line)
            vectors.append(vector)
            labels.append(label)
    return


def load_single_image(file):
    vector = []

    with open(file, "r") as f:
        for line in f:
            line = int(line.strip())
            line = threshold(line)
            vector.append(line)

    return vector


def calculate_distances_to_new_point(new_vector):
    results = {}

    for i in range(len(vectors)):
        distance = 0
        for j in range(len(vectors[i])):
            distance += abs(vectors[i][j] - new_vector[j])

        results["{}_{}".format(labels[i], distance)] = distance

    return results


if __name__ == "__main__":
    load_training_data()

    v = load_single_image(sys.argv[1])
    results = calculate_distances_to_new_point(v)

    sorted = sorted(results.items(), key=operator.itemgetter(1))

    for s in sorted:
        print(s)
