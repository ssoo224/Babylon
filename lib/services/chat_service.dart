import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils.dart';

typedef Json = Map<String, dynamic>;

class Msg {
  final String id;
  final Json d;
  Msg(this.id, this.d);
  String get senderId => d['senderId'] ?? '';
  String get text => d['text'] ?? '';
  bool get read => d['read'] == true;
  int get createdAt => (d['createdAt'] as num?)?.toInt() ?? 0;
  String? get imageUrl => d['imageUrl'];
  String? get audioUrl => d['audioUrl'];
  String? get videoUrl => d['videoUrl'];
  String? get caption => d['caption'];
  String? get replyTo => d['replyTo'];
  String get type => d['type'] ?? '';
  int get duration => (d['duration'] as num?)?.toInt() ?? 0;
  String get preview => audioUrl != null
      ? '♬ بصمة صوتية'
      : imageUrl != null
          ? '▧ صورة'
          : videoUrl != null
              ? '▶ فيديو'
              : text;

  Map<String, dynamic> get reactions =>
      Map<String, dynamic>.from((d['reactions'] as Map?) ?? {});
}

class ChatService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Json> get _chats => _db.collection('chats');
  CollectionReference<Json> get _users => _db.collection('users');

  // ---------- المحادثات ----------
  Stream<List<QueryDocumentSnapshot<Json>>> chatsStream(String uid) => _chats
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((s) {
        final l = s.docs.toList()
          ..sort((a, b) => ((b.data()['updatedAt'] ?? 0) as num)
              .compareTo((a.data()['updatedAt'] ?? 0) as num));
        return l;
      });

  Future<String> ensureChat(String me, String other) async {
    final id = pairChatId(me, other);
    final ref = _chats.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [me, other],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    return id;
  }

  Stream<Json> chatDoc(String chatId) =>
      _chats.doc(chatId).snapshots().map((d) => d.data() ?? {});

  Stream<Json?> userStream(String uid) =>
      _users.doc(uid).snapshots().map((d) => d.data());

  Future<Json?> getUser(String uid) async => (await _users.doc(uid).get()).data();

  /// البحث بيوزر: usernames/{username} -> uid -> users/{uid}
  Future<Json?> findByUsername(String username) async {
    var u = username.trim().toLowerCase();
    if (u.startsWith('@')) u = u.substring(1);
    if (u.isEmpty) return null;
    final d = await _db.collection('usernames').doc(u).get();
    final uid = d.data()?['uid'] as String?;
    if (uid == null) return null;
    final user = await getUser(uid);
    if (user == null) return null;
    return {...user, 'id': user['id'] ?? uid};
  }

  // ---------- الرسائل ----------
  Stream<List<Msg>> messages(String chatId, {int limit = 50}) => _chats
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => Msg(d.id, d.data())).toList());

  /// آخر رسالة للمعاينة في قائمة المحادثات (مثل نسخة الويب: limit 1)
  Stream<Msg?> lastMessage(String chatId) => _chats
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : Msg(s.docs.first.id, s.docs.first.data()));

  Future<void> _touch(String chatId, String me, {Json extra = const {}}) =>
      _chats.doc(chatId).set({
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'typing_$me': false,
        ...extra,
      }, SetOptions(merge: true));

  Future<void> send(
    String chatId,
    String me,
    Json payload, {
    Msg? replyTo,
  }) async {
    final data = <String, dynamic>{
      'senderId': me,
      'read': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      ...payload,
    };
    if (replyTo != null) {
      data['replyTo'] = replyTo.text.isNotEmpty
          ? replyTo.text
          : (replyTo.audioUrl != null ? '🎤 رسالة صوتية' : '📷 صورة');
      data['replyToId'] = replyTo.id;
      data['replyToSenderId'] = replyTo.senderId;
    }
    await _chats.doc(chatId).collection('messages').add(data);
    await _touch(chatId, me);
  }

  Future<void> editMessage(String chatId, String id, String text) =>
      _chats.doc(chatId).collection('messages').doc(id).update({'text': text});

  Future<void> deleteMessage(String chatId, String id) =>
      _chats.doc(chatId).collection('messages').doc(id).delete();

  /// لكل مستخدم تفاعل واحد: reactions.<uid>
  Future<void> react(String chatId, String id, String me, String? emoji) =>
      _chats.doc(chatId).collection('messages').doc(id).update({
        'reactions.$me': emoji == null ? FieldValue.delete() : emoji,
      });

  Future<void> markRead(String chatId, String me, List<Msg> msgs) async {
    final un = msgs.where((m) => m.senderId != me && !m.read).toList();
    if (un.isEmpty) return;
    final b = _db.batch();
    for (final m in un) {
      b.update(_chats.doc(chatId).collection('messages').doc(m.id),
          {'read': true});
    }
    await b.commit().catchError((_) {});
  }

  Future<void> setTyping(String chatId, String me, bool v) => _chats
      .doc(chatId)
      .set({'typing_$me': v}, SetOptions(merge: true))
      .catchError((_) {});

  // ---------- الحظر ----------
  Stream<Set<String>> blocks(String me) => _users
      .doc(me)
      .collection('blocks')
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toSet());

  Future<void> block(String me, String other) => _users
      .doc(me)
      .collection('blocks')
      .doc(other)
      .set({'at': DateTime.now().millisecondsSinceEpoch});

  Future<void> unblock(String me, String other) =>
      _users.doc(me).collection('blocks').doc(other).delete();

  /// هل الطرف الآخر حظرني؟
  Stream<bool> blockedBy(String me, String other) => _users
      .doc(other)
      .collection('blocks')
      .doc(me)
      .snapshots()
      .map((d) => d.exists);

  // ---------- القصص ----------
  Stream<List<Json>> activeStories() => _db
      .collection('stories')
      .where('expiresAt', isGreaterThan: DateTime.now().millisecondsSinceEpoch)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList()
        ..sort((a, b) => ((a['createdAt'] ?? 0) as num)
            .compareTo((b['createdAt'] ?? 0) as num)));

  Future<String?> postStory(
    String me, {
    required String imageDataUrl,
    String caption = '',
    int hours = 24,
  }) async {
    final mine = await _db.collection('stories').where('userId', isEqualTo: me).get();
    final now = DateTime.now().millisecondsSinceEpoch;
    final active = mine.docs.where((d) => ((d.data()['expiresAt'] ?? 0) as num) > now);
    if (active.length >= 3) return 'وصلت إلى الحد الأقصى: 3 قصص نشطة';
    await _db.collection('stories').add({
      'userId': me,
      'imageUrl': imageDataUrl,
      'caption': caption,
      'createdAt': now,
      'expiresAt': now + hours * 3600000,
      'pinned': false,
    });
    final until = now + hours * 3600000;
    await _users.doc(me).set({'storyUntil': until, 'storyAt': now}, SetOptions(merge: true));
    return null;
  }

  Future<void> markStoryViewed(String storyId, String me, String name) => _db
      .collection('stories')
      .doc(storyId)
      .collection('views')
      .doc(me)
      .set({'at': DateTime.now().millisecondsSinceEpoch, 'name': name},
          SetOptions(merge: true))
      .catchError((_) {});

  Future<void> deleteStory(String id) => _db.collection('stories').doc(id).delete();
}
