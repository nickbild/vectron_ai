####
# Nick Bild
# nick.bild@gmail.com
# Control Atari 2600 emulator via GPIO.
####
import RPi.GPIO as GPIO
import pyautogui


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
        pyautogui.keyDown('up')
        time.sleep(key_hold_time_sec)
        pyautogui.keyUp('up')

    if GPIO.event_detected(down) == True:
        pyautogui.keyDown('down')
        time.sleep(key_hold_time_sec)
        pyautogui.keyUp('down')

    if GPIO.event_detected(left) == True:
        pyautogui.keyDown('left')
        time.sleep(key_hold_time_sec)
        pyautogui.keyUp('left')

    if GPIO.event_detected(right) == True:
        pyautogui.keyDown('right')
        time.sleep(key_hold_time_sec)
        pyautogui.keyUp('right')

