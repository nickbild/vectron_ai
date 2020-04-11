import RPi.GPIO as GPIO
import time


GPIO.setmode(GPIO.BOARD)

data = 8
latch = 10
clock = 12
interrupt = 16

delay_time = 0.000001

GPIO.setup(data, GPIO.OUT, initial=GPIO.LOW)
GPIO.setup(latch, GPIO.OUT, initial=GPIO.LOW)
GPIO.setup(clock, GPIO.OUT, initial=GPIO.LOW)
GPIO.setup(interrupt, GPIO.OUT, initial=GPIO.LOW)

GPIO.output(data, 0)                # Qh
GPIO.output(clock, GPIO.HIGH)
time.sleep(delay_time)
GPIO.output(clock, GPIO.LOW)
time.sleep(delay_time)

GPIO.output(data, 1)
GPIO.output(clock, GPIO.HIGH)
time.sleep(delay_time)
GPIO.output(clock, GPIO.LOW)
time.sleep(delay_time)

GPIO.output(data, 0)
GPIO.output(clock, GPIO.HIGH)
time.sleep(delay_time)
GPIO.output(clock, GPIO.LOW)
time.sleep(delay_time)

GPIO.output(data, 0)
GPIO.output(clock, GPIO.HIGH)
time.sleep(delay_time)
GPIO.output(clock, GPIO.LOW)
time.sleep(delay_time)

GPIO.output(data, 0)
GPIO.output(clock, GPIO.HIGH)
time.sleep(delay_time)
GPIO.output(clock, GPIO.LOW)
time.sleep(delay_time)

GPIO.output(data, 0)
GPIO.output(clock, GPIO.HIGH)
time.sleep(delay_time)
GPIO.output(clock, GPIO.LOW)
time.sleep(delay_time)

GPIO.output(data, 0)
GPIO.output(clock, GPIO.HIGH)
time.sleep(delay_time)
GPIO.output(clock, GPIO.LOW)
time.sleep(delay_time)

GPIO.output(data, 1)            # Qa
GPIO.output(clock, GPIO.HIGH)
time.sleep(delay_time)
GPIO.output(clock, GPIO.LOW)
time.sleep(delay_time)

GPIO.output(latch, GPIO.HIGH)
time.sleep(delay_time)
GPIO.output(latch, GPIO.LOW)

while True:
    GPIO.output(interrupt, GPIO.HIGH)
    time.sleep(2)
    GPIO.output(interrupt, GPIO.LOW)
    time.sleep(2)

