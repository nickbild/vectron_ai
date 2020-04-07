import glob


vectors = []
labels = []


def read_in_data():
    files = glob.glob("train/up/image_*.txt")
    for file in files:
        label = "up"
        with open(file, "r") as f:
            vector = []
            for line in f:
                line = int(line.strip())
                vector.append(line)
            vectors.append(vector)
            labels.append(label)


def calculate_all_distances():
    for i in range(len(vectors)-1):
        for j in range(i+1, len(vectors)):
            distance = 0
            for k in range(len(vectors[i])):
                distance += abs(vectors[i][k] - vectors[j][k])
            print("{}-{}: {}".format(i, j, distance))


read_in_data()
print(vectors)
print(labels)

calculate_all_distances()
