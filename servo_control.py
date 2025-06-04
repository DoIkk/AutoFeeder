# servo_control.py
import RPi.GPIO as GPIO
import time

servo_pwm = None
servo_pin = None  # 추가

# Initialize servo
def init_servo(pin):
    global servo_pwm, servo_pin
    servo_pin = pin
    GPIO.setup(pin, GPIO.OUT)
    servo_pwm = GPIO.PWM(pin, 50)
    servo_pwm.start(0)

# Set servo angle (0–180 degrees)
def set_angle(angle):
    duty = 2.5 + (angle / 180.0) * 10
    servo_pwm.ChangeDutyCycle(duty)
    time.sleep(1)
    servo_pwm.ChangeDutyCycle(0)
