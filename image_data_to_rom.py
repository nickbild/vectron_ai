folders = ["train/up", "train/down", "train/left", "train/right", "train/nothing"]
start = 0
end = 20


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


for folder in folders:
	for cnt in range(start, end):
		print("Image{}_{}".format(cnt, folder.split("/")[-1]))
		with open('{}/image_{}.txt'.format(folder, cnt), 'r') as f:
			for line in f:
				line = line.strip()
				line = threshold(int(line))
				print("    .byte #${}".format("{0:0{1}x}".format(line, 2)))
		print("")
