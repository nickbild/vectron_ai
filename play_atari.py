####
# Nick Bild
# nick.bild@gmail.com
# Control Atari 2600 emulator via GPIO.
####
import RPi.GPIO as GPIO


up = 8
down = 10
left = 12
right = 16

GPIO.setmode(GPIO.BOARD)

GPIO.setup(up, GPIO.IN)
GPIO.setup(down, GPIO.IN)
GPIO.setup(left, GPIO.IN)
GPIO.setup(right, GPIO.IN)

GPIO.add_event_detect(up, GPIO.FALLING)
GPIO.add_event_detect(down, GPIO.FALLING)
GPIO.add_event_detect(left, GPIO.FALLING)
GPIO.add_event_detect(right, GPIO.FALLING)


while True:
    # Check for an input
    if GPIO.event_detected(up) == True:
        pass

    if GPIO.event_detected(down) == True:
        pass

    if GPIO.event_detected(left) == True:
        pass

    if GPIO.event_detected(right) == True:
        pass
