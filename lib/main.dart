import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'add_device_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/key.env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: WaterDashboardApp()));
}

class WaterDashboardApp extends StatelessWidget {
  const WaterDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCV Water Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

// 保留舊測試相容名稱
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const WaterDashboardApp();
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCV 智慧水資源監控'),
        backgroundColor: Colors.deepPurple.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "新增裝置 (AI)",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddDevicePage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sensors')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("錯誤: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.devices_other, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    "目前沒有裝置",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddDevicePage()),
                    ),
                    child: const Text("點擊右上角 [+] 新增"),
                  ),
                ],
              ),
            );
          }

          final devices = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final deviceData = devices[index].data() as Map<String, dynamic>;

              return SensorCard(
                deviceId: deviceData['id'],
                place: deviceData['place'] ?? '未命名區域',
                schema: deviceData['schema'] ?? {},
              );
            },
          );
        },
      ),
    );
  }
}

class SensorCard extends StatelessWidget {
  final String deviceId;
  final Map<String, dynamic> schema;
  final String place;

  const SensorCard({
    super.key,
    required this.deviceId,
    required this.schema,
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> fields = schema['fields'] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("ID: $deviceId", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                const Icon(Icons.water_drop, color: Colors.blueAccent),
              ],
            ),
            const Divider(height: 24),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('readings')
                  .doc(deviceId)
                  .collection('stream')
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Text("數據異常");
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text("等待數據連接...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
                }

                final latestData = snapshot.data!.docs.first.data() as Map<String, dynamic>;

                return Column(
                  children: fields.map((field) {
                    final key = field['key'];
                    final label = field['label'] ?? key;
                    final unit = field['unit'] ?? '';
                    final double value = (latestData[key] ?? 0).toDouble();
                    final double maxVal = (field['max_threshold'] ?? 1000).toDouble();
                    final double percent = (value / maxVal).clamp(0.0, 1.0);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label, style: TextStyle(color: Colors.grey[800])),
                              Text(
                                "${value.toStringAsFixed(1)} $unit",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: percent > 0.8 ? Colors.red : Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                percent > 0.8 ? Colors.redAccent : Colors.blueAccent,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
