# yolov8_detect.py
import time
import cv2
import os

# Detect person for at least 10 seconds using YOLO
def detect_person(model, picam2, output_dir):
    frame_count = 0
    detect_start = None
    detection_duration = 0

    while True:
        frame = picam2.capture_array()
        results = model(frame)
        annotated_frame = results[0].plot()
        classes = results[0].boxes.cls.tolist()

        if 0 in classes:  # class 0 = person
            if detect_start is None:
                detect_start = time.time()
            else:
                detection_duration = time.time() - detect_start

            if detection_duration >= 10:
                return True
        else:
            detect_start = None
            detection_duration = 0

        output_path = os.path.join(output_dir, f"frame_{frame_count:04d}.jpg")
        cv2.imwrite(output_path, annotated_frame)
        print(f"[INFO] Saved: {output_path}")
        frame_count += 1

        cv2.imshow("YOLOv8 Detection", annotated_frame)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    return False
