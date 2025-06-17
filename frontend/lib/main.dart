import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

// 전역 변수로 서버 IP 주소 관리
String SERVER_IP = '192.168.0.10';
String get serverUrl => 'http://$SERVER_IP:5000';

void main() => runApp(PetFeederApp());

class PetFeederApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen());
  }
}

// 스플래시
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _loadServerIP();
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    });
  }

  Future<void> _loadServerIP() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIP = prefs.getString('server_ip');
    if (savedIP != null && savedIP.isNotEmpty) {
      SERVER_IP = savedIP;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'PetFeeder',
              style: TextStyle(
                fontSize: 32,
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
            ),
            SizedBox(height: 20),
            Text('서버 연결 중...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// 홈 페이지
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> schedules = [];
  List<String> dogs = [];
  bool isServerConnected = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkServerConnection();
  }

  // 서버 연결 상태 확인
  Future<void> _checkServerConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('$serverUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 5));

      setState(() {
        isServerConnected = response.statusCode == 200;
      });

      if (isServerConnected) {
        print('✅ 서버 연결 성공: $serverUrl');
      } else {
        print('❌ 서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isServerConnected = false;
      });
      print('❌ 서버 연결 실패: $e');
    }
  }

  // 저장된 데이터 불러오기
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 강아지 목록 불러오기
    final dogsString = prefs.getString('dogs');
    if (dogsString != null) {
      final dogsList = List<String>.from(json.decode(dogsString));
      setState(() {
        dogs = dogsList;
      });
    }

    // 스케줄 목록 불러오기
    final schedulesString = prefs.getString('schedules');
    if (schedulesString != null) {
      final schedulesList = List<Map<String, dynamic>>.from(
        json
            .decode(schedulesString)
            .map((item) => Map<String, dynamic>.from(item)),
      );
      setState(() {
        schedules = schedulesList;
      });
    }
  }

  // 데이터 저장하기
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dogs', json.encode(dogs));
    await prefs.setString('schedules', json.encode(schedules));
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool requiresServer = false,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: requiresServer && !isServerConnected
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('서버에 연결되지 않았습니다. 설정을 확인해주세요.'),
                    action: SnackBarAction(
                      label: '설정',
                      onPressed: () => _showServerSettings(),
                    ),
                  ),
                );
              }
            : onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: requiresServer && !isServerConnected
                    ? Colors.grey
                    : Colors.deepOrange,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: requiresServer && !isServerConnected
                        ? Colors.grey
                        : Colors.black,
                  ),
                ),
              ),
              if (requiresServer) ...[
                Icon(
                  isServerConnected ? Icons.wifi : Icons.wifi_off,
                  color: isServerConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 서버 설정 다이얼로그
  void _showServerSettings() {
    final controller = TextEditingController(text: SERVER_IP);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('서버 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('라즈베리파이의 IP 주소를 입력하세요:'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'IP 주소',
                hintText: '예: 192.168.0.10',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 16),
            Text(
              '현재 연결 상태: ${isServerConnected ? "연결됨" : "연결 안됨"}',
              style: TextStyle(
                color: isServerConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final newIP = controller.text.trim();
              if (newIP.isNotEmpty) {
                SERVER_IP = newIP;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('server_ip', newIP);
                Navigator.pop(context);
                await _checkServerConnection();
                setState(() {});
              }
            },
            child: Text('저장'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkServerConnection();
            },
            child: Text('연결 테스트'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('PetFeeder', style: TextStyle(color: Colors.deepOrange)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // 서버 연결 상태 표시
          Container(
            margin: EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Icon(
                  isServerConnected ? Icons.wifi : Icons.wifi_off,
                  color: isServerConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  isServerConnected ? '연결됨' : '연결안됨',
                  style: TextStyle(
                    color: isServerConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.deepOrange),
            onPressed: _showServerSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 📅 오늘의 급식 스케줄 카드
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pets, color: Colors.deepOrange),
                        SizedBox(width: 8),
                        Text(
                          '오늘의 급식 스케줄',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${schedules.where((s) => s['enabled'] == true).length}개 활성화',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    schedules
                            .where((schedule) => schedule['enabled'] == true)
                            .isEmpty
                        ? Text('활성화된 스케줄이 없습니다.\n스케줄을 추가하거나 활성화해주세요.')
                        : Column(
                            children: schedules
                                .where(
                                  (schedule) => schedule['enabled'] == true,
                                )
                                .map((schedule) {
                                  return Container(
                                    margin: EdgeInsets.symmetric(vertical: 4),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${schedule['dog']}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              '${schedule['repeat']}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${schedule['time']}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.deepOrange
                                                .withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '${schedule['amount']}',
                                            style: TextStyle(
                                              color: Colors.deepOrange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                  ],
                ),
              ),
            ),

            // ➕ 급식 스케줄 추가
            _buildCard(
              icon: Icons.schedule,
              title: '급식 스케줄 추가',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SchedulePage(existingSchedules: schedules, dogs: dogs),
                  ),
                );
                if (result != null) {
                  setState(() {
                    schedules = result['schedules'];
                    dogs = result['dogs'];
                  });
                  await _saveData(); // 데이터 저장
                }
              },
            ),

            _buildCard(
              icon: Icons.account_circle,
              title: '강아지 프로필 관리',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DogProfilePage(dogs: dogs)),
                );
                if (result != null) {
                  setState(() {
                    dogs = result;
                  });
                  await _saveData(); // 데이터 저장
                }
              },
            ),

            // 🐶 밥먹는 모습 보기
            _buildCard(
              icon: Icons.camera,
              title: '밥먹는 모습 보기',
              requiresServer: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeedingCamScreen()),
                );
              },
            ),

            // 📁 지난 급식 내역 보기
            _buildCard(
              icon: Icons.history,
              title: '지난 급식 내역 보기',
              requiresServer: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PastScheduleScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 📁 지난 급식 내역 더미 페이지
class FeedHistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('지난 급식 내역')),
      body: Center(child: Text('급식 기록이 여기에 표시됩니다')),
    );
  }
}

// 🔧 더미 페이지
// class DummyPage extends StatelessWidget {
//   final String title;

//   DummyPage({required this.title});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(title)),
//       body: Center(child: Text('$title 화면입니다. (추후 구현)')),
//     );
//   }
// }

class SchedulePage extends StatefulWidget {
  final List<Map<String, dynamic>> existingSchedules;
  final List<String> dogs;

  SchedulePage({required this.existingSchedules, required this.dogs});

  @override
  _SchedulePageState createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late List<Map<String, dynamic>> schedules;
  late List<String> dogs;

  @override
  void initState() {
    super.initState();
    schedules = List.from(widget.existingSchedules);
    dogs = List.from(widget.dogs);
  }

  void addSchedule(String dog, String time, String repeat, String amount) {
    setState(() {
      schedules.add({
        'dog': dog,
        'time': time,
        'repeat': repeat,
        'amount': amount,
        'enabled': true,
      });
    });
  }

  void removeSchedule(int index) {
    setState(() {
      schedules.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () =>
              Navigator.pop(context, {'schedules': schedules, 'dogs': dogs}),
        ),
        title: Text('급식 스케줄 설정', style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          Expanded(
            child: schedules.isEmpty
                ? Center(child: Text('등록된 스케줄이 없습니다.\n아래 버튼을 눌러 스케줄을 추가해보세요.'))
                : ListView.builder(
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      final item = schedules[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item['time'],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                item['dog'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          title: Text(item['repeat']),
                          subtitle: Text('급식량 약 ${item['amount']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: item['enabled'],
                                onChanged: (val) {
                                  setState(() {
                                    item['enabled'] = val;
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => removeSchedule(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () async {
                if (dogs.isEmpty) {
                  // 강아지가 없으면 알림 표시
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('먼저 강아지 프로필을 등록해주세요!'),
                      action: SnackBarAction(
                        label: '등록하기',
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DogProfilePage(dogs: dogs),
                            ),
                          );
                          if (result != null) {
                            setState(() {
                              dogs = result;
                            });
                          }
                        },
                      ),
                    ),
                  );
                  return;
                }

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSchedulePage(dogs: dogs),
                  ),
                );
                if (result != null) {
                  addSchedule(
                    result['dog'],
                    result['time'],
                    result['repeat'],
                    result['amount'],
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                minimumSize: Size.fromHeight(50),
              ),
              child: Text(
                '스케줄 추가',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddSchedulePage extends StatefulWidget {
  final List<String> dogs;

  AddSchedulePage({required this.dogs});

  @override
  _AddSchedulePageState createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  TimeOfDay selectedTime = TimeOfDay.now();
  String repeat = '한번만';
  String amount = '6g';
  late String selectedDog;
  String? selectedVoice;
  List<String> availableVoices = [];

  @override
  void initState() {
    super.initState();
    // 강아지 리스트가 비어있지 않을 경우 첫 번째 강아지를 선택
    selectedDog = widget.dogs.isNotEmpty ? widget.dogs.first : '';
    if (selectedDog.isNotEmpty) {
      _loadVoicesForDog(selectedDog);
    }
  }

  Future<void> _loadVoicesForDog(String dogName) async {
    final prefs = await SharedPreferences.getInstance();
    final voices = prefs.getStringList('voiceList_$dogName') ?? [];
    final currentSelectedVoice = prefs.getString('selectedVoice_$dogName');

    setState(() {
      availableVoices = voices;
      selectedVoice = currentSelectedVoice;
    });
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  void _saveSchedule() async {
    if (selectedDog.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('강아지를 선택해주세요!')));
      return;
    }

    // 시간 형식 변환 (e.g., 오전 6:30 → 06:30)
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final formattedTime =
        "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";

    // 선택된 음성 확인
    if (selectedVoice == null || selectedVoice!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('음성을 선택해주세요!'),
          action: availableVoices.isEmpty
              ? SnackBarAction(
                  label: '녹음하기',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VoiceRecordPage(dogName: selectedDog),
                      ),
                    ).then((_) => _loadVoicesForDog(selectedDog));
                  },
                )
              : null,
        ),
      );
      return;
    }

    final voicePath = selectedVoice!;

    // 라즈베리파이에 음성 파일 업로드 후 스케줄 전송
    try {
      final voiceFile = File(voicePath);
      if (await voiceFile.exists()) {
        await uploadVoiceFile(voiceFile, voicePath.split('/').last);
      }

      await sendSchedule(
        dog: selectedDog,
        time: formattedTime,
        voice: voicePath.split('/').last, // 파일명만 추출
        amount: int.tryParse(amount.replaceAll(RegExp(r'[^0-9]'), '')) ?? 10,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('스케줄 전송 중 오류가 발생했습니다: $e')));
      return;
    }

    // Flutter 쪽에 스케줄 정보 반환
    Navigator.pop(context, {
      'dog': selectedDog,
      'time': formattedTime,
      'repeat': repeat,
      'amount': amount,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('스케줄 설정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [],
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('시간'),
            trailing: TextButton(
              onPressed: () => _selectTime(context),
              child: Text(
                selectedTime.format(context),
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          Divider(),
          ListTile(
            title: Text('반복'),
            trailing: DropdownButton<String>(
              value: repeat,
              items: [
                '한번만',
                '매일',
                '월,수,금',
                '주말',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => repeat = val!),
            ),
          ),
          Divider(),
          ListTile(
            title: Text('급식량'),
            trailing: DropdownButton<String>(
              value: amount,
              items: [
                '6g',
                '10g',
                '20g',
                '30g',
                '50g',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => amount = val!),
            ),
          ),
          Divider(),
          ListTile(
            title: Text('강아지 선택'),
            trailing: widget.dogs.isEmpty
                ? Text('등록된 강아지가 없습니다', style: TextStyle(color: Colors.grey))
                : DropdownButton<String>(
                    value: selectedDog.isNotEmpty ? selectedDog : null,
                    hint: Text('강아지 선택'),
                    items: widget.dogs
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedDog = val!;
                        selectedVoice = null; // 강아지 변경시 음성 초기화
                      });
                      _loadVoicesForDog(val!); // 새 강아지의 음성 목록 로드
                    },
                  ),
          ),
          Divider(),
          ListTile(
            title: Text('음성 선택'),
            subtitle: selectedDog.isEmpty
                ? Text('먼저 강아지를 선택해주세요')
                : availableVoices.isEmpty
                ? Text('등록된 음성이 없습니다')
                : selectedVoice != null
                ? Text('선택됨: ${selectedVoice!.split('/').last}')
                : Text('음성을 선택해주세요'),
            trailing: selectedDog.isEmpty || availableVoices.isEmpty
                ? ElevatedButton(
                    onPressed: selectedDog.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VoiceRecordPage(dogName: selectedDog),
                              ),
                            ).then((_) => _loadVoicesForDog(selectedDog));
                          },
                    child: Text('음성 녹음'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: selectedVoice,
                        hint: Text('음성 선택'),
                        items: availableVoices.map((voice) {
                          final fileName = voice.split('/').last;
                          return DropdownMenuItem(
                            value: voice,
                            child: Text(
                              fileName.length > 20
                                  ? '${fileName.substring(0, 20)}...'
                                  : fileName,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedVoice = val),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VoiceRecordPage(dogName: selectedDog),
                            ),
                          ).then((_) => _loadVoicesForDog(selectedDog));
                        },
                        icon: Icon(Icons.mic, color: Colors.deepOrange),
                      ),
                    ],
                  ),
          ),
          if (widget.dogs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DogProfilePage(dogs: [])),
                  );
                  if (result != null && result.isNotEmpty) {
                    setState(() {
                      selectedDog = result.first;
                    });
                    Navigator.pop(context, result); // 강아지 목록을 이전 페이지로 전달
                  }
                },
                child: Text('강아지 프로필 등록하기'),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _saveSchedule,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            minimumSize: Size.fromHeight(50),
          ),
          child: Text(
            '저장',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class DogProfilePage extends StatefulWidget {
  final List<String> dogs;

  const DogProfilePage({required this.dogs, Key? key}) : super(key: key);

  @override
  _DogProfilePageState createState() => _DogProfilePageState();
}

class _DogProfilePageState extends State<DogProfilePage> {
  late List<String> dogList;
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    dogList = List.from(widget.dogs);
  }

  void _addDog() {
    if (controller.text.trim().isNotEmpty) {
      if (!dogList.contains(controller.text.trim())) {
        setState(() {
          dogList.add(controller.text.trim());
          controller.clear();
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('이미 등록된 강아지입니다!')));
      }
    }
  }

  void _removeDog(int index) {
    setState(() {
      dogList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('강아지 프로필 관리'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: dogList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pets, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '등록된 강아지가 없습니다.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          '아래에서 강아지를 추가해보세요!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: dogList.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepOrange,
                            child: Icon(Icons.pets, color: Colors.white),
                          ),
                          title: Text(
                            dogList[index],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VoiceRecordPage(dogName: dogList[index]),
                              ),
                            );
                          },
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeDog(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: '강아지 이름 추가',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add),
                      onPressed: _addDog,
                    ),
                  ),
                  onSubmitted: (_) => _addDog(),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, dogList),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    minimumSize: Size.fromHeight(50),
                  ),
                  child: Text(
                    '저장',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🎤 음성 녹음 페이지 - 수정된 버전
class VoiceRecordPage extends StatefulWidget {
  final String dogName;
  const VoiceRecordPage({required this.dogName, Key? key}) : super(key: key);

  @override
  _VoiceRecordPageState createState() => _VoiceRecordPageState();
}

class _VoiceRecordPageState extends State<VoiceRecordPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecording = false;
  String? _recordingPath;

  List<String> savedVoices = [];
  String? selectedVoicePath;

  @override
  void initState() {
    super.initState();
    _init();
    _loadSavedVoices();
  }

  Future<void> _init() async {
    try {
      // 권한 요청을 더 명확하게
      final microphonePermission = await Permission.microphone.request();
      if (microphonePermission != PermissionStatus.granted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('마이크 권한이 필요합니다.')));
        return;
      }

      // 레코더와 플레이어 초기화
      await _recorder.openRecorder();
      await _player.openPlayer();

      print('✅ 녹음기 초기화 완료');
    } catch (e) {
      print('❌ 초기화 실패: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('녹음기 초기화에 실패했습니다: $e')));
    }
  }

  Future<void> _loadSavedVoices() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('voiceList_${widget.dogName}') ?? [];
    final selected = prefs.getString('selectedVoice_${widget.dogName}');
    setState(() {
      savedVoices = list;
      selectedVoicePath = selected;
    });
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        // 녹음 중지
        final path = await _recorder.stopRecorder();
        print('녹음 완료: $path');
        setState(() {
          _isRecording = false;
          _hasRecording = true;
          _recordingPath = path;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('녹음이 완료되었습니다!')));
      } else {
        // 녹음 시작
        final appDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'voice_temp_${widget.dogName}_$timestamp.aac';
        final tempPath = '${appDir.path}/$fileName';

        print('녹음 시작: $tempPath');
        print('앱 디렉토리: ${appDir.path}');

        // 파일명만 전달 (flutter_sound가 자동으로 경로 처리)
        await _recorder.startRecorder(toFile: fileName, codec: Codec.aacADTS);

        setState(() {
          _isRecording = true;
          _hasRecording = false;
          _recordingPath = tempPath; // 전체 경로를 저장
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('녹음을 시작합니다...')));
      }
    } catch (e) {
      print('❌ 녹음 오류: $e');
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('녹음 중 오류가 발생했습니다: $e')));
    }
  }

  Future<void> _playRecording(String path) async {
    try {
      if (!_isPlaying) {
        setState(() => _isPlaying = true);
        await _player.startPlayer(
          fromURI: path,
          codec: Codec.aacADTS, // 코덱 명시적 지정
          whenFinished: () {
            setState(() => _isPlaying = false);
            print('재생 완료');
          },
        );
      }
    } catch (e) {
      print('❌ 재생 오류: $e');
      setState(() => _isPlaying = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('재생 중 오류가 발생했습니다: $e')));
    }
  }

  Future<void> _stopPlaying() async {
    try {
      if (_isPlaying) {
        await _player.stopPlayer();
        setState(() => _isPlaying = false);
      }
    } catch (e) {
      print('❌ 재생 중지 오류: $e');
    }
  }

  Future<void> _saveVoice() async {
    if (_recordingPath != null) {
      try {
        final tempFile = File(_recordingPath!);

        // 파일이 실제로 존재하는지 확인
        if (!await tempFile.exists()) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('녹음 파일을 찾을 수 없습니다.')));
          return;
        }

        final appDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '_');
        final savedPath =
            '${appDir.path}/voice_${widget.dogName}_$timestamp.aac';

        await tempFile.copy(savedPath);

        final prefs = await SharedPreferences.getInstance();
        final updatedList =
            prefs.getStringList('voiceList_${widget.dogName}') ?? [];
        updatedList.add(savedPath);
        await prefs.setStringList('voiceList_${widget.dogName}', updatedList);

        setState(() {
          savedVoices = updatedList;
          _hasRecording = false; // 저장 후 임시 녹음 상태 초기화
          _recordingPath = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.dogName}의 음성이 저장되었습니다.')),
        );
      } catch (e) {
        print('❌ 저장 오류: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')));
      }
    }
  }

  void _selectVoice(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedVoice_${widget.dogName}', path);
    setState(() => selectedVoicePath = path);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('음성이 선택되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.dogName} 음성 녹음'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 녹음 상태 표시
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.red.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isRecording ? Icons.fiber_manual_record : Icons.mic,
                    color: _isRecording ? Colors.red : Colors.grey,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _isRecording ? '녹음 중...' : '녹음 대기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _isRecording ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            Expanded(
              child: savedVoices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic_none, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            '녹음된 음성이 없습니다.',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          Text(
                            '아래 마이크 버튼을 눌러 녹음해보세요!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: savedVoices.length,
                      itemBuilder: (context, index) {
                        final path = savedVoices[index];
                        final isSelected = path == selectedVoicePath;
                        final fileName = path.split('/').last;

                        return Card(
                          elevation: isSelected ? 4 : 2,
                          color: isSelected
                              ? Colors.green.withOpacity(0.1)
                              : null,
                          child: ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.audiotrack,
                              color: isSelected
                                  ? Colors.green
                                  : Colors.deepOrange,
                            ),
                            title: Text('녹음파일 ${index + 1}'),
                            subtitle: Text(
                              fileName,
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _playRecording(path),
                                  icon: Icon(Icons.play_arrow),
                                ),
                                ElevatedButton(
                                  onPressed: () => _selectVoice(path),
                                  child: Text(isSelected ? '✅ 선택됨' : '선택'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? Colors.green
                                        : Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            SizedBox(height: 16),

            // 임시 녹음 파일 재생/저장 버튼
            if (_hasRecording) ...[
              Card(
                color: Colors.orange.withOpacity(0.1),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '새로 녹음된 파일',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isPlaying
                                ? null
                                : () => _playRecording(_recordingPath!),
                            icon: Icon(Icons.play_arrow),
                            label: Text('재생'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isPlaying ? _stopPlaying : null,
                            icon: Icon(Icons.stop),
                            label: Text('멈춤'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveVoice,
                          icon: Icon(Icons.save),
                          label: Text('음성 저장'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            if (!_hasRecording && !_isRecording)
              Text(
                '마이크를 눌러 새로운 음성을 녹음하세요.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),

            SizedBox(height: 16),

            // 녹음 버튼
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.deepOrange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.red : Colors.deepOrange)
                          .withOpacity(0.3),
                      spreadRadius: _isRecording ? 8 : 4,
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),

            SizedBox(height: 16),
            Text(
              _isRecording ? '녹음을 중지하려면 다시 누르세요' : '녹음을 시작하려면 누르세요',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> sendSchedule({
  required String dog,
  required String time, // "HH:mm"
  required String voice,
  required int amount,
}) async {
  final url = Uri.parse('$serverUrl/set-schedule');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'dog': dog,
      'time': time,
      'voice': voice,
      'amount': amount,
    }),
  );

  if (response.statusCode == 200) {
    print('Schedule sent: ${response.body}');
  } else {
    print('Failed to send schedule: ${response.statusCode}');
  }
}

Future<void> uploadVoiceFile(File file, String filename) async {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$serverUrl/upload-voice'),
  );
  request.files.add(
    await http.MultipartFile.fromPath('file', file.path, filename: filename),
  );

  final response = await request.send();
  if (response.statusCode == 200) {
    print('✅ 음성 파일 업로드 성공');
  } else {
    print('❌ 업로드 실패');
  }
}

// ────────────────────────────────────────────────
// 지난 급식 내역 화면
class PastScheduleScreen extends StatefulWidget {
  const PastScheduleScreen({super.key});
  @override
  State<PastScheduleScreen> createState() => _PastScheduleScreenState();
}

class _PastScheduleScreenState extends State<PastScheduleScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchHistory();
  }

  Future<List<dynamic>> _fetchHistory() async {
    try {
      final res = await http
          .get(
            Uri.parse('$serverUrl/past-schedules'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data;
        } else {
          throw Exception('잘못된 데이터 형식');
        }
      } else {
        throw Exception('서버 오류 (${res.statusCode})');
      }
    } catch (e) {
      throw Exception('서버 연결 실패: $e');
    }
  }

  String _formatDateTime(String datetime) {
    try {
      final parsed = DateTime.parse(datetime);
      return '${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return datetime.length > 16 ? datetime.substring(5, 16) : datetime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지난 급식 내역'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _future = _fetchHistory();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.deepOrange,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '급식 내역을 불러오는 중...',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    SizedBox(height: 16),
                    Text(
                      '데이터를 불러올 수 없습니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _future = _fetchHistory();
                        });
                      },
                      icon: Icon(Icons.refresh),
                      label: Text('다시 시도'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    '급식 기록이 없습니다',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '스케줄이 실행되면 여기에 기록이 나타납니다.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final response = await http.post(
                          Uri.parse('$serverUrl/add-test-history'),
                          headers: {'Content-Type': 'application/json'},
                        );
                        if (response.statusCode == 200) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('테스트 데이터가 추가되었습니다!')),
                          );
                          setState(() {
                            _future = _fetchHistory();
                          });
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('테스트 데이터 추가 실패: $e')),
                        );
                      }
                    },
                    icon: Icon(Icons.add),
                    label: Text('테스트 데이터 추가'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = list[index];
              final datetime = item['datetime'] ?? '';
              final dog = item['dog'] ?? '알 수 없는 강아지';
              final amount = item['amount'] ?? 0;
              final status = item['status'] ?? 'completed';

              // 상태에 따른 색상 및 아이콘 설정
              final isScheduled = status == 'scheduled';
              final statusColor = isScheduled ? Colors.blue : Colors.green;
              final statusText = isScheduled ? '예정' : '완료';
              final iconData = isScheduled ? Icons.schedule : Icons.pets;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(iconData, color: statusColor),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dog,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              '급식량: ${amount}g',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _formatDateTime(datetime),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────
class FeedingCamScreen extends StatefulWidget {
  const FeedingCamScreen({super.key});
  @override
  State<FeedingCamScreen> createState() => _FeedingCamScreenState();
}

class _FeedingCamScreenState extends State<FeedingCamScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _serverChecked = false;

  @override
  void initState() {
    super.initState();
    _checkServerAndCamera();
  }

  // 서버 및 카메라 상태 확인
  Future<void> _checkServerAndCamera() async {
    try {
      print('🔍 서버 연결 확인 중... ($serverUrl)');

      // 먼저 서버 연결 확인
      final healthResponse = await http
          .get(
            Uri.parse('$serverUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 5));

      if (healthResponse.statusCode != 200) {
        throw Exception('서버 응답 오류 (${healthResponse.statusCode})');
      }

      print('✅ 서버 연결 성공');
      print('🔍 카메라 상태 확인 중...');

      // 카메라 상태 확인
      final cameraResponse = await http
          .get(
            Uri.parse('$serverUrl/camera-status'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 3));

      if (cameraResponse.statusCode == 200) {
        final cameraData = json.decode(cameraResponse.body);
        final cameraAvailable = cameraData['available'] ?? false;

        print('📷 카메라 상태: ${cameraAvailable ? "사용 가능" : "사용 불가"}');

        if (!cameraAvailable) {
          // 카메라 재초기화 시도
          print('🔄 카메라 재초기화 시도 중...');
          await _reinitCamera();
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _serverChecked = true;
        });
      }

      print('✅ 서버 및 카메라 상태 확인 완료');
    } catch (e) {
      print('❌ 서버 연결 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _serverChecked = true;
          _errorMessage =
              '서버에 연결할 수 없습니다.\n서버 주소: $serverUrl\n오류: $e\n\n서버가 실행 중인지 확인해주세요.';
        });
      }
    }
  }

  // 카메라 재초기화
  Future<void> _reinitCamera() async {
    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl/reinit-camera'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔄 카메라 재초기화: ${data['message']}');
      }
    } catch (e) {
      print('⚠️ 카메라 재초기화 실패: $e');
    }
  }

  // 카메라 디버그 정보 가져오기
  Future<void> _getCameraDebugInfo() async {
    try {
      final response = await http
          .get(
            Uri.parse('$serverUrl/camera-debug'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final debugData = json.decode(response.body);
        print('🐛 카메라 디버그 정보: $debugData');

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('카메라 디버그 정보'),
              content: SingleChildScrollView(
                child: Text(
                  '카메라 사용 가능: ${debugData['camera_available']}\n'
                  'Picamera2 사용 가능: ${debugData['picamera2_available']}\n'
                  'Picam2 활성: ${debugData['picam2_active']}\n'
                  'OpenCV 활성: ${debugData['opencv_camera_active']}\n'
                  '시간: ${debugData['system_info']['time']}\n\n'
                  '전체 정보:\n${debugData.toString()}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('⚠️ 디버그 정보 가져오기 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('밥먹는 모습 실시간'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: _hasError
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.white70),
                    SizedBox(height: 16),
                    Text(
                      '카메라 연결 실패',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _isLoading = true;
                              _serverChecked = false;
                            });
                            _checkServerAndCamera(); // 서버 상태 다시 확인
                          },
                          child: Text('다시 시도'),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _getCameraDebugInfo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('디버그'),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                          _hasError = false;
                        });
                        await _reinitCamera();
                        await _checkServerAndCamera();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('카메라 재시작'),
                    ),
                  ],
                ),
              )
            : _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '카메라 연결 중...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
            : Center(
                child: AspectRatio(
                  aspectRatio: 4 / 3, // 카메라 비율
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _CameraStreamWidget(
                        streamUrl: '$serverUrl/video_feed',
                        onError: (error) {
                          setState(() {
                            _hasError = true;
                            _errorMessage = '카메라 스트리밍 오류:\n$error';
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// MJPEG 스트림을 처리하는 커스텀 위젯
class _CameraStreamWidget extends StatefulWidget {
  final String streamUrl;
  final Function(String)? onError;

  const _CameraStreamWidget({Key? key, required this.streamUrl, this.onError})
    : super(key: key);

  @override
  _CameraStreamWidgetState createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends State<_CameraStreamWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _retryCount = 0;
  final int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _loadStream();
  }

  void _loadStream() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // MJPEG 스트림을 표시하는 Image.network
          Image.network(
            widget.streamUrl,
            fit: BoxFit.cover,
            headers: {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
              'Connection': 'keep-alive',
              'Accept': 'multipart/x-mixed-replace, image/jpeg',
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                // 로딩 완료
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _hasError = false;
                    });
                  }
                });
                return child;
              }

              // 로딩 중
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '카메라 스트림 연결 중...',
                        style: TextStyle(color: Colors.white),
                      ),
                      if (loadingProgress.expectedTotalBytes != null)
                        Text(
                          '${(loadingProgress.cumulativeBytesLoaded / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('❌ 카메라 스트림 오류: $error');

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_hasError) {
                  setState(() {
                    _hasError = true;
                    _isLoading = false;
                    _errorMessage = '스트림 연결 실패: $error';
                  });

                  // 에러 콜백 호출
                  if (widget.onError != null) {
                    widget.onError!(_errorMessage);
                  }
                }
              });

              return Container(
                color: Colors.grey[900],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off, size: 64, color: Colors.white54),
                      SizedBox(height: 16),
                      Text(
                        '카메라 오류',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'MJPEG 스트림 로드 실패',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 16),
                      if (_retryCount < _maxRetries)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _retryCount++;
                            });
                            _loadStream();
                          },
                          child: Text('재시도 ($_retryCount/$_maxRetries)'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 로딩 오버레이
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '카메라 스트림 초기화 중...',
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      widget.streamUrl,
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
