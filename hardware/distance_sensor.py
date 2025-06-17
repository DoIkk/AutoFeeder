# distance_sensor.py
import RPi.GPIO as GPIO
import time

TRIG = 23
ECHO = 24

# Initialize ultrasonic sensor
def init_distance_sensor():
    GPIO.setup(TRIG, GPIO.OUT)
    GPIO.setup(ECHO, GPIO.IN)

# Measure distance in cm
def measure_distance():
    GPIO.output(TRIG, False)
    time.sleep(0.05)

    GPIO.output(TRIG, True)
    time.sleep(0.00001)
    GPIO.output(TRIG, False)

    start = time.time()
    while GPIO.input(ECHO) == 0:
        start = time.time()
    while GPIO.input(ECHO) == 1:
        end = time.time()

    duration = end - start
    distance = duration * 17150
    return round(distance, 2)
