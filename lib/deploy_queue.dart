import 'package:cloud_firestore/cloud_firestore.dart';

/// 透過 Firestore 觸發 Cloud Function 執行 SSH 部署
class DeployQueue {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 提交部署請求，回傳 document ID（可用來監聽狀態）
  Future<String> submitDeploy({
    required String deviceId,
    required String piHost,
    int piPort = 22,
    String piUser = 'pi',
    String action = 'deploy',
    String? sensorDescription,
    Map<String, dynamic>? schema,
    Map<String, dynamic>? firebaseConfig,
  }) async {
    final doc = await _db.collection('deploy_queue').add({
      'device_id': deviceId,
      'pi_host': piHost,
      'pi_port': piPort,
      'pi_user': piUser,
      'action': action,
      'sensor_description': sensorDescription ?? '',
      'schema': schema ?? {},
      'firebase_config': firebaseConfig ?? {},
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// 監聽部署狀態
  Stream<DocumentSnapshot> watchStatus(String docId) {
    return _db.collection('deploy_queue').doc(docId).snapshots();
  }

  /// 提交遠端操控請求（start/stop/restart/status）
  Future<String> submitRemoteAction({
    required String deviceId,
    required String piHost,
    required String action,
  }) async {
    final doc = await _db.collection('deploy_queue').add({
      'device_id': deviceId,
      'pi_host': piHost,
      'pi_port': 22,
      'pi_user': 'pi',
      'action': action,
      'sensor_description': '',
      'schema': {},
      'firebase_config': {},
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }
}
