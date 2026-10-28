// ランキング用の Firebase の設定。
// 委員会が Firebase のプロジェクトを作ったら、docs/ranking_setup.md の手順で値を入れる。
// apiKey が空のあいだは、ランキングは「準備中」と表示され、Firebase には一切つながない。
import 'package:firebase_core/firebase_core.dart';

/// 学校のGoogleアカウントのドメイン（例：@の後ろ）。firestore.rules の schoolDomain() と同じ値にする
const schoolDomain = '';

const firebaseWebOptions = FirebaseOptions(
  apiKey: '',
  appId: '',
  messagingSenderId: '',
  projectId: '',
  authDomain: '',
);

bool get rankingConfigured => firebaseWebOptions.apiKey.isNotEmpty && schoolDomain.isNotEmpty;
