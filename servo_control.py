# servo_control.py
import RPi.GPIO as GPIO
import time

servo_pwm = None

# Initialize servo
def init_servo(pin):
    global servo_pwm
    GPIO.setup(pin, GPIO.OUT)
    servo_pwm = GPIO.PWM(pin, 50)
    servo_pwm.start(0)

# Set servo angle (0–180 degrees)
def set_angle(angle):
    duty = angle / 18 + 2
    GPIO.output(17, True)
    servo_pwm.ChangeDutyCycle(duty)
    time.sleep(0.5)
    GPIO.output(17, False)
    servo_pwm.ChangeDutyCycle(0)
