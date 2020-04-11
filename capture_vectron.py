####
# Nick Bild
# nick.bild@gmail.com
# Capture realtime images and transfer to Vectron 64.
####
import picamera
import time
from PIL import Image
import numpy as np


with picamera.PiCamera() as camera:
    # Configure and warm up camera.
    camera.color_effects = (128, 128)
    camera.resolution = (320, 240)
    camera.rotation = 180
    time.sleep(2)

    while True:
        print("Capturing image...")

        # Capture a downsampled frame.
        camera.capture('current.bmp', format='bmp', resize=(10, 10))

        # Retrieve pixel data.
        im = Image.open('current.bmp')
        p = np.array(im)

        # Serialize and reduce dimensionality.
        p = p.flatten()[0::3]

        for v in p:
            print(v)
            bin = '{0:08b}'.format(v)
            print(bin)
            for bit in bin:
                print(bit)
            print("----")

        time.sleep(5)
