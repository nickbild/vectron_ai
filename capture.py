import picamera
import time
from PIL import Image
import numpy as np


with picamera.PiCamera() as camera:
    # Configure and warm up camera.
    camera.color_effects = (128,128)
    camera.resolution = (320,240)
    camera.rotation = 180
    time.sleep(2)

    # Capture a downsampled frame.
    camera.capture('test.bmp', format='bmp', resize=(10, 10))

    # Retrieve pixel data.
    im = Image.open("test.bmp")
    p = np.array(im)

    print(p)

