# main.py
import time
import cv2
import os
import RPi.GPIO as GPIO
from picamera2 import Picamera2
from ultralytics import YOLO

from servo_control import set_angle, init_servo
from distance_sensor import measure_distance, init_distance_sensor
from yolov8_detect import detect_person

# === Configuration ===
SERVO = 17
USE_WEIGHT_SENSOR = True  # Set to True if HX711 is connected
HX_DT = 5
HX_SCK = 6
output_dir = "/home/yourusername/Desktop/output/"  # Change this path to your environment
os.makedirs(output_dir, exist_ok=True)

# === Initialization ===
GPIO.setmode(GPIO.BCM)
init_servo(SERVO)
init_distance_sensor()

# HX711 (only if used)
if USE_WEIGHT_SENSOR:
    from hx711 import HX711
    hx = HX711(HX_DT, HX_SCK)
    hx.set_reference_unit(22)  # Adjust this based on calibration
    hx.tare()

# YOLO and Camera setup
model = YOLO("yolov8n.pt")
picam2 = Picamera2()
picam2.preview_configuration.main.size = (640, 480)
picam2.preview_configuration.main.format = "RGB888"
picam2.configure("preview")
picam2.start()

try:
    while True:
        dist = measure_distance()
        print(f"[Ultrasonic] Distance: {dist} cm")

        if dist <= 30:
            print("✅ Distance condition met. Starting YOLO detection.")
            person_detected = detect_person(model, picam2, output_dir)

            if person_detected:
                print("✅ 'person' detected for 10 seconds → opening servo.")
                set_angle(90)
                time.sleep(1)

                if USE_WEIGHT_SENSOR:
                    target_weight = 30  # grams
                    print(f"🎯 Target weight: {target_weight}g")
                    while True:
                        weight = hx.get_weight()
                        print(f"[Weight Sensor] Current: {round(weight, 1)}g")
                        if weight >= target_weight:
                            print("✅ Target reached → closing servo.")
                            set_angle(0)
                            break
                        time.sleep(0.5)
                else:
                    print("🕒 Simulating feeding for 5 seconds...")
                    time.sleep(5)
                    print("✅ Done feeding → closing servo.")
                    set_angle(0)

        time.sleep(1)

except KeyboardInterrupt:
    print("🛑 Program terminated by user.")

finally:
    servo.stop()
    GPIO.cleanup()
    cv2.destroyAllWindows()
