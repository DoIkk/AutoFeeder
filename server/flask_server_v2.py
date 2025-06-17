from flask import Flask, request, jsonify
import schedule
import time
import threading
import subprocess
import os
import json
from datetime import datetime

import cv2
from flask import Response
import atexit

# 라즈베리파이 카메라 지원
try:
    from picamera2 import Picamera2
    PICAMERA_AVAILABLE = True
    print("✅ Picamera2 사용 가능")
except ImportError:
    PICAMERA_AVAILABLE = False
    print("⚠️ Picamera2 없음 - OpenCV 사용")

app = Flask(__name__)
jobs = []  # 여러 개 스케줄 저장용
SCHEDULE_FILE = 'saved_schedules.json'
HISTORY_FILE = 'feeding_history.json'  # 급식 이력 저장

# 카메라 초기화 및 에러 처리 개선
camera = None
picam2 = None
camera_available = False

def init_camera():
    global camera, picam2, camera_available, PICAMERA_AVAILABLE
    try:
        if PICAMERA_AVAILABLE:
            # 라즈베리파이 카메라 사용
            print("📷 Picamera2로 카메라 초기화 중...")
            picam2 = Picamera2()
            picam2.preview_configuration.main.size = (640, 480)
            picam2.preview_configuration.main.format = "RGB888"
            picam2.configure("preview")
            picam2.start()
            
            # 테스트 프레임 캡처
            frame = picam2.capture_array()
            if frame is not None and frame.size > 0:
                camera_available = True
                print("✅ Picamera2 초기화 성공")
            else:
                camera_available = False
                print("❌ Picamera2에서 프레임을 읽을 수 없음")
        else:
            # 백업: OpenCV 웹캠 사용
            print("📷 OpenCV로 카메라 초기화 중...")
            camera = cv2.VideoCapture(0)
            if camera.isOpened():
                camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                # 테스트 프레임 읽기
                ret, frame = camera.read()
                if ret:
                    camera_available = True
                    print("✅ OpenCV 카메라 초기화 성공")
                else:
                    camera_available = False
                    print("❌ OpenCV 카메라에서 프레임을 읽을 수 없음")
            else:
                camera_available = False
                print("❌ OpenCV 카메라를 열 수 없음")
                
    except Exception as e:
        camera_available = False
        print(f"❌ 카메라 초기화 실패: {e}")

# 서버 시작시 카메라 초기화
init_camera()

# 카메라 해제 함수
def release_camera():
    global camera, picam2
    try:
        if picam2 is not None:
            picam2.stop()
            print("📹 Picamera2 리소스 해제")
        if camera is not None:
            camera.release()
            print("📹 OpenCV 카메라 리소스 해제")
    except Exception as e:
        print(f"⚠️ 카메라 해제 오류: {e}")

atexit.register(release_camera)

# 📌 급식 이력 저장 함수
def save_feeding_history(dog, time_str, voice, amount, status='completed'):
    history_data = []
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE, 'r', encoding='utf-8') as f:
                history_data = json.load(f)
        except:
            history_data = []
    
    # 새 이력 추가
    new_record = {
        'dog': dog,
        'time': time_str,
        'voice': voice,
        'amount': amount,
        'status': status,  # 'scheduled' 또는 'completed'
        'datetime': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }
    history_data.append(new_record)
    print(f"📝 급식 이력 저장: {new_record}")
    
    # 최근 100개만 유지
    if len(history_data) > 100:
        history_data = history_data[-100:]
    
    # 파일에 저장
    try:
        with open(HISTORY_FILE, 'w', encoding='utf-8') as f:
            json.dump(history_data, f, ensure_ascii=False, indent=2)
        print(f"✅ 급식 이력 파일 저장 완료 (총 {len(history_data)}개)")
    except Exception as e:
        print(f"❌ 급식 이력 저장 실패: {e}")

# 📌 테스트용 급식 이력 생성 함수
def create_sample_history():
    if not os.path.exists(HISTORY_FILE):
        sample_data = [
            {
                'dog': '초코',
                'time': '08:00',
                'voice': 'sample_voice.aac',
                'amount': 20,
                'status': 'completed',
                'datetime': '2024-01-15 08:00:00'
            },
            {
                'dog': '쿠키',
                'time': '12:00',
                'voice': 'sample_voice2.aac',
                'amount': 15,
                'status': 'completed',
                'datetime': '2024-01-15 12:00:00'
            },
            {
                'dog': '초코',
                'time': '18:00',
                'voice': 'sample_voice.aac',
                'amount': 25,
                'status': 'scheduled',
                'datetime': '2024-01-15 18:00:00'
            }
        ]
        
        try:
            with open(HISTORY_FILE, 'w', encoding='utf-8') as f:
                json.dump(sample_data, f, ensure_ascii=False, indent=2)
            print(f"✅ 샘플 급식 이력 생성 완료 ({len(sample_data)}개)")
        except Exception as e:
            print(f"❌ 샘플 데이터 생성 실패: {e}")

# 📌 카메라 프레임 생성 함수 (Picamera2 지원)
def generate_frames():
    global camera, picam2, camera_available, PICAMERA_AVAILABLE
    
    frame_count = 0
    
    while True:
        if not camera_available:
            # 카메라가 없을 때 더미 이미지 반환
            import numpy as np
            dummy_frame = np.zeros((480, 640, 3), dtype=np.uint8)
            
            # 현재 시간 텍스트 추가
            current_time = datetime.now().strftime('%H:%M:%S')
            cv2.putText(dummy_frame, 'Camera Not Available', (150, 200), 
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
            cv2.putText(dummy_frame, f'Time: {current_time}', (180, 250), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (200, 200, 200), 2)
            cv2.putText(dummy_frame, 'Check Camera Connection', (120, 300), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.8, (150, 150, 150), 2)
            
            ret, buffer = cv2.imencode('.jpg', dummy_frame)
            frame = buffer.tobytes()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
            time.sleep(1)  # 1초 간격으로 더미 프레임 전송
            
        else:
            try:
                if PICAMERA_AVAILABLE and picam2 is not None:
                    # Picamera2 사용
                    frame = picam2.capture_array()
                    if frame is not None and frame.size > 0:
                        # RGB to BGR 변환 (OpenCV 형식)
                        frame_bgr = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
                        
                        # 프레임 번호 추가 (선택사항)
                        cv2.putText(frame_bgr, f'Frame: {frame_count}', (10, 30), 
                                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                        
                        ret, buffer = cv2.imencode('.jpg', frame_bgr)
                        if ret:
                            frame_bytes = buffer.tobytes()
                            yield (b'--frame\r\n'
                                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
                        frame_count += 1
                        time.sleep(0.033)  # ~30 FPS
                    else:
                        print("⚠️ Picamera2 프레임 캡처 실패")
                        camera_available = False
                        
                elif camera is not None:
                    # OpenCV 사용
                    success, frame = camera.read()
                    if success and frame is not None:
                        # 프레임 번호 추가 (선택사항)
                        cv2.putText(frame, f'Frame: {frame_count}', (10, 30), 
                                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                        
                        ret, buffer = cv2.imencode('.jpg', frame)
                        if ret:
                            frame_bytes = buffer.tobytes()
                            yield (b'--frame\r\n'
                                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
                        frame_count += 1
                        time.sleep(0.033)  # ~30 FPS
                    else:
                        print("⚠️ OpenCV 프레임 읽기 실패")
                        camera_available = False
                else:
                    print("❌ 사용 가능한 카메라가 없음")
                    camera_available = False
                    
            except Exception as e:
                print(f"❌ 프레임 생성 오류: {e}")
                camera_available = False
                time.sleep(1)

# 📌 스케줄 실행 스레드
def run_scheduler():
    print("🚀 스케줄러 시작")
    while True:
        schedule.run_pending()
        time.sleep(1)

# 📌 스케줄 등록 내부 함수
def set_schedule_internal(dog, time_str, voice, amount):
    def run_main():
        print(f"🍽️ [{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {dog} 급식 시작")
        try:
            result = subprocess.run([
                'python3', 'main.py',
                '--dog', dog,
                '--voice', voice,
                '--amount', str(amount)
            ],capture_output=True, text=True, timeout=120)
            if result.returncode == 0:
                print(f"✅ {dog} 급식 완료")
                # 급식 성공 시 이력 저장 (완료 상태로)
                save_feeding_history(dog, time_str, voice, amount, status='completed')
            else:
                print(f"❌ 급식 실패: {result.stderr}")
        except Exception as e:
            print(f"💥 실행 오류: {e}")

    job = schedule.every().day.at(time_str).do(run_main)
    jobs.append({
        'dog': dog,
        'time': time_str,
        'voice': voice,
        'amount': amount,
        'job': job
    })

# 📌 저장된 스케줄을 불러오기
def load_schedules():
    if os.path.exists(SCHEDULE_FILE):
        try:
            with open(SCHEDULE_FILE, 'r', encoding='utf-8') as f:
                saved = json.load(f)
                for item in saved:
                    set_schedule_internal(item['dog'], item['time'], item['voice'], item['amount'])
            print(f"✅ {len(saved)}개 스케줄 복원 완료")
        except Exception as e:
            print(f"❌ 스케줄 복원 실패: {e}")

# 📌 현재 스케줄을 저장
def save_schedules():
    save_data = [
        {k: v for k, v in item.items() if k != 'job'}
        for item in jobs
    ]
    with open(SCHEDULE_FILE, 'w', encoding='utf-8') as f:
        json.dump(save_data, f, ensure_ascii=False, indent=2)

# 📌 스케줄 등록 API
@app.route('/set-schedule', methods=['POST'])
def set_schedule():
    try:
        data = request.get_json()
        dog = data['dog']
        time_str = data['time']
        voice = data['voice']
        amount = data['amount']

        set_schedule_internal(dog, time_str, voice, amount)
        save_schedules()
        
        # 스케줄 추가와 동시에 급식 이력에도 저장 (예정 상태로)
        save_feeding_history(dog, time_str, voice, amount, status='scheduled')

        return jsonify({'status': '스케줄 등록 완료'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 📌 스케줄 목록 조회
@app.route('/schedules', methods=['GET'])
def get_schedules():
    return jsonify([
        {k: v for k, v in item.items() if k != 'job'}
        for item in jobs
    ])

# 📌 스케줄 삭제
@app.route('/delete-schedule', methods=['POST'])
def delete_schedule():
    try:
        data = request.get_json()
        dog = data['dog']
        time_str = data['time']

        # 조건에 맞는 항목 찾기
        target = None
        for job in jobs:
            if job['dog'] == dog and job['time'] == time_str:
                target = job
                break

        if target:
            schedule.cancel_job(target['job'])
            jobs.remove(target)
            save_schedules()
            return jsonify({'status': '삭제 완료'}), 200
        else:
            return jsonify({'error': '해당 스케줄 없음'}), 404

    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 📌 음성 파일 업로드
@app.route('/upload-voice', methods=['POST'])
def upload_voice():
    try:
        file = request.files['file']
        save_dir = os.path.join(os.getcwd(), "voices")
        os.makedirs(save_dir, exist_ok=True)
        save_path = os.path.join(save_dir, file.filename)

        print(f"🔹 저장할 파일 경로: {save_path}")  

        file.save(save_path)
        return jsonify({'status': 'saved', 'filename': file.filename}), 200
    except Exception as e:
        print(f"❌ 업로드 실패: {e}")  
        return jsonify({'error': str(e)}), 500

# 📌 카메라 스트리밍 엔드포인트 (개선된 버전)
@app.route('/video_feed')
def video_feed():
    return Response(generate_frames(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')

# 📌 카메라 상태 확인 엔드포인트
@app.route('/camera-status')
def camera_status():
    global camera_available, picam2, camera, PICAMERA_AVAILABLE
    
    status_info = {
        'available': camera_available,
        'picamera2_available': PICAMERA_AVAILABLE,
        'picam2_active': picam2 is not None,
        'opencv_camera_active': camera is not None,
        'message': '카메라 사용 가능' if camera_available else '카메라 사용 불가'
    }
    
    if not camera_available:
        status_info['troubleshooting'] = [
            "1. 카메라 케이블 연결 확인",
            "2. 'sudo raspi-config'에서 카메라 활성화",
            "3. 'vcgencmd get_camera' 명령어로 카메라 감지 확인",
            "4. 다른 프로그램에서 카메라 사용 중인지 확인"
        ]
    
    return jsonify(status_info)

# 📌 카메라 재초기화 엔드포인트
@app.route('/reinit-camera', methods=['POST'])
def reinit_camera():
    try:
        # 기존 카메라 해제
        release_camera()
        time.sleep(2)  # 2초 대기
        
        # 카메라 재초기화
        init_camera()
        
        return jsonify({
            'success': True,
            'camera_available': camera_available,
            'message': '카메라 재초기화 성공' if camera_available else '카메라 재초기화 실패'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'camera_available': False,
            'message': f'카메라 재초기화 오류: {str(e)}'
        }), 500

# 📌 카메라 디버그 정보 엔드포인트  
@app.route('/camera-debug')
def camera_debug():
    debug_info = {
        'camera_available': camera_available,
        'picamera2_available': PICAMERA_AVAILABLE,
        'picam2_object': str(type(picam2)),
        'camera_object': str(type(camera)),
        'system_info': {
            'os': os.name,
            'time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    }
    
    # Picamera2 상태 확인
    if PICAMERA_AVAILABLE and picam2 is not None:
        try:
            debug_info['picam2_status'] = 'running'
            debug_info['picam2_config'] = str(picam2.camera_configuration)
        except Exception as e:
            debug_info['picam2_status'] = f'error: {str(e)}'
    
    # OpenCV 카메라 상태 확인
    if camera is not None:
        try:
            debug_info['opencv_status'] = 'opened' if camera.isOpened() else 'closed'
        except Exception as e:
            debug_info['opencv_status'] = f'error: {str(e)}'
    
    return jsonify(debug_info)

# 📌 지난 급식 내역 조회 엔드포인트 (개선된 버전)
@app.route('/past-schedules', methods=['GET'])
def get_past_schedules():
    try:
        print(f"🔍 급식 이력 파일 확인: {HISTORY_FILE}")
        if os.path.exists(HISTORY_FILE):
            with open(HISTORY_FILE, 'r', encoding='utf-8') as f:
                history_data = json.load(f)
                print(f"📋 불러온 이력 개수: {len(history_data)}")
                # 최신 순으로 정렬
                history_data.sort(key=lambda x: x['datetime'], reverse=True)
                return jsonify(history_data)
        else:
            print("📋 급식 이력 파일이 없음 - 빈 배열 반환")
            return jsonify([])
    except Exception as e:
        print(f"❌ 급식 이력 조회 오류: {e}")
        return jsonify({'error': str(e)}), 500

# 📌 테스트용 급식 이력 추가 엔드포인트
@app.route('/add-test-history', methods=['POST'])
def add_test_history():
    try:
        # 현재 시간으로 테스트 데이터 추가
        save_feeding_history(
            dog='테스트견',
            time_str=datetime.now().strftime('%H:%M'),
            voice='test_voice.aac',
            amount=15,
            status='completed'
        )
        return jsonify({'status': '테스트 이력 추가 완료'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 📌 서버 상태 확인 엔드포인트
@app.route('/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'camera_available': camera_available,
        'schedules_count': len(jobs)
    })

# 📌 서버 시작
if __name__ == '__main__':
    print("🐶 펫피더 서버 시작 중...")
    create_sample_history()  # 샘플 데이터 생성
    load_schedules()
    threading.Thread(target=run_scheduler, daemon=True).start()
    print("🌐 서버가 http://0.0.0.0:5000 에서 시작됩니다")
    print("📱 Flutter 앱에서 다음 주소들로 접근하세요:")
    print("   - 카메라: http://[라즈베리파이IP]:5000/video_feed")
    print("   - 급식이력: http://[라즈베리파이IP]:5000/past-schedules")
    print("   - 서버상태: http://[라즈베리파이IP]:5000/health")
    app.run(host='0.0.0.0', port=5000, debug=True)
