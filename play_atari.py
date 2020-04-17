####
# Nick Bild
# nick.bild@gmail.com
# Control Atari 2600 emulator via GPIO.
####
import RPi.GPIO as GPIO
import autopy


key_hold_time_sec = 0.1

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
        autopy.key.toggle(autopy.key.Code.UP_ARROW, True, [], 0)
        time.sleep(key_hold_time_sec)
        autopy.key.toggle(autopy.key.Code.UP_ARROW, False, [], 0)

    if GPIO.event_detected(down) == True:
        autopy.key.toggle(autopy.key.Code.DOWN_ARROW, True, [], 0)
        time.sleep(key_hold_time_sec)
        autopy.key.toggle(autopy.key.Code.DOWN_ARROW, False, [], 0)

    if GPIO.event_detected(left) == True:
        autopy.key.toggle(autopy.key.Code.LEFT_ARROW, True, [], 0)
        time.sleep(key_hold_time_sec)
        autopy.key.toggle(autopy.key.Code.LEFT_ARROW, False, [], 0)

    if GPIO.event_detected(right) == True:
        autopy.key.toggle(autopy.key.Code.RIGHT_ARROW, True, [], 0)
        time.sleep(key_hold_time_sec)
        autopy.key.toggle(autopy.key.Code.RIGHT_ARROW, False, [], 0)
