####
# Nick Bild
# nick.bild@gmail.com
# Capture realtime images and transfer to Vectron 64.
####
import picamera
import time
from PIL import Image
import numpy as np
import RPi.GPIO as GPIO


GPIO.setmode(GPIO.BOARD)

delay_time = 0.000001

data = 8
latch = 10
clock = 12

interrupt = 16
interrupt_clear = 18

# Shift register.
GPIO.setup(data, GPIO.OUT, initial=GPIO.LOW)
GPIO.setup(latch, GPIO.OUT, initial=GPIO.LOW)
GPIO.setup(clock, GPIO.OUT, initial=GPIO.LOW)

# Vectron 64 communication.
GPIO.setup(interrupt, GPIO.OUT, initial=GPIO.HIGH)
GPIO.setup(interrupt_clear, GPIO.IN)


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


def push_to_sr(v):
    GPIO.output(data, v)
    GPIO.output(clock, GPIO.HIGH)
    time.sleep(delay_time)
    GPIO.output(clock, GPIO.LOW)
    time.sleep(delay_time)


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

        # For each byte...
        for v in p:
            # Downscale value and convert to binary string.
            v = threshold(v)
            bin = '{0:08b}'.format(v)

            # Write each bit to shift register.
            for bit in bin: # MSB -> Qh.
                push_to_sr(int(bit))

            # Latch the byte.
            GPIO.output(latch, GPIO.HIGH)
            time.sleep(delay_time)
            GPIO.output(latch, GPIO.LOW)

            # Send interrupt to Vectron 64.
            GPIO.output(interrupt, GPIO.LOW)
            time.sleep(0.00002) # 20 microseconds
            GPIO.output(interrupt, GPIO.HIGH)

            # Wait for interrupt to clear.
            GPIO.wait_for_edge(interrupt_clear, GPIO.FALLING)
