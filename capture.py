import picamera
import time
from PIL import Image
import numpy as np


folder = "train/up"
start = 0
end = 2


with picamera.PiCamera() as camera:
    # Configure and warm up camera.
    camera.color_effects = (128, 128)
    camera.resolution = (320, 240)
    camera.rotation = 180
    time.sleep(2)

    for cnt in range(start, end+1):
        print("Capturing image: {}".format(cnt))

        # Capture a downsampled frame.
        camera.capture('img/{}/image_{}.bmp'.format(folder, cnt), format='bmp', resize=(10, 10))

        # Retrieve pixel data.
        im = Image.open('img/{}/image_{}.bmp'.format(folder, cnt))
        p = np.array(im)

        # Serialize and reduce dimensionality.
        p = p.flatten()[0::3]
        #print(p)

        with open('{}/image_{}.txt'.format(folder, cnt), 'w') as f:
            f.writelines("%s\n" % v for v in p)

