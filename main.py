# main.py

import time
import cv2
import os
import argparse
import subprocess
import RPi.GPIO as GPIO
from picamera2 import Picamera2
from ultralytics import YOLO

from servo_control import set_angle, init_servo
from distance_sensor import measure_distance, init_distance_sensor
from yolov8_detect import detect_person

# === CLI 인자 처리 ===
parser = argparse.ArgumentParser()
parser.add_argument('--dog', required=True)
parser.add_argument('--voice', required=True)
parser.add_argument('--amount', type=int, required=True)
args = parser.parse_args()

dog = args.dog
voice_file = args.voice
target_weight = args.amount

# === Configuration ===
SERVO = 17
USE_WEIGHT_SENSOR = True
HX_DT = 5
HX_SCK = 6
output_dir = "/home/pi/auto_feeder/output"
voice_dir = "/home/pi/auto_feeder/voices"
os.makedirs(output_dir, exist_ok=True)

# === Initialization ===
GPIO.setmode(GPIO.BCM)
init_servo(SERVO)
init_distance_sensor()

if USE_WEIGHT_SENSOR:
    from hx711 import HX711
    hx = HX711(HX_DT, HX_SCK)
    hx.set_reference_unit(22)
    hx.tare()

# === 음성 재생 ===
voice_path = os.path.join(voice_dir, voice_file)
if os.path.exists(voice_path):
    print(f"🔊 Playing voice: {voice_path}")
    subprocess.run(['mpg123', voice_path])
else:
    print(f"⚠️ Voice file not found: {voice_path}")

# === YOLO + 급식 루프 ===
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
                print("✅ 'person' detected → opening servo.")
                set_angle(90)
                time.sleep(1)

                if USE_WEIGHT_SENSOR:
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
    GPIO.cleanup()
    cv2.destroyAllWindows()
