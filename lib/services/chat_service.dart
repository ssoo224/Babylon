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
  bool get system => d['system'] == true;
  bool get forwarded => d['forwarded'] == true;
  String? get posterUrl => d['posterUrl'];
  bool get storyReply => d['storyReply'] == true;
  Map<String, dynamic>? get storyReplyData =>
      d['storyReplyData'] is Map ? Map<String, dynamic>.from(d['storyReplyData']) : null;
  List<String> get deletedFor => ((d['deletedFor'] as List?) ?? []).cast<String>();
  bool get isMedia => imageUrl != null || videoUrl != null || audioUrl != null;
  int get duration => (d['duration'] as num?)?.toInt() ?? 0;
  String get preview => storyReply
      ? '↩ ${text.isEmpty ? 'رد على قصة' : text}'
      : audioUrl != null
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
    bool group = false,
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
    final preview = (payload['text'] as String?) ??
        (payload['audioUrl'] != null ? '♬ بصمة صوتية' : '▧ صورة');
    await _touch(chatId, me, extra: group
        ? {
            'lastMsg': {'text': preview, 'senderId': me, 'at': data['createdAt']},
            'readAt': {me: data['createdAt']},
          }
        : const {});
  }

  /// حذف لدي فقط: deletedFor = [uid]
  Future<void> deleteForMe(String chatId, String id, String me) => _chats
      .doc(chatId)
      .collection('messages')
      .doc(id)
      .update({'deletedFor': FieldValue.arrayUnion([me])});

  /// إعادة توجيه (نفس حقول الأصل: forwarded:true)
  Future<void> forward(String targetChatId, String me, List<Msg> msgs, {bool group = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var last = '';
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final n = <String, dynamic>{
        'senderId': me,
        'forwarded': true,
        'read': false,
        'createdAt': now + i,
      };
      if (m.text.isNotEmpty) n['text'] = m.text;
      if (m.imageUrl != null) n['imageUrl'] = m.imageUrl;
      if (m.videoUrl != null) {
        n['videoUrl'] = m.videoUrl;
        if (m.posterUrl != null) n['posterUrl'] = m.posterUrl;
      }
      if (m.audioUrl != null) n['audioUrl'] = m.audioUrl;
      if (m.duration > 0) n['duration'] = m.duration;
      if (m.d['thumb'] != null) n['thumb'] = m.d['thumb'];
      if (m.type == 'sticker') {
        n['type'] = 'sticker';
        if (m.d['sticker'] != null) n['sticker'] = m.d['sticker'];
      }
      await _chats.doc(targetChatId).collection('messages').add(n);
      last = m.preview;
    }
    await _chats.doc(targetChatId).set({
      'updatedAt': now + msgs.length,
      if (group) 'lastMsg': {'text': last, 'senderId': me, 'at': now},
    }, SetOptions(merge: true));
  }

  /// عدد غير المقروء (رسائل الطرف الآخر read=false)
  Stream<int> unreadCount(String chatId, String me) => _chats
      .doc(chatId)
      .collection('messages')
      .where('read', isEqualTo: false)
      .limit(60)
      .snapshots()
      .map((s) => s.docs.where((d) {
            final m = d.data();
            return m['senderId'] != me &&
                m['system'] != true &&
                !(((m['deletedFor'] as List?) ?? []).contains(me));
          }).length);

  // ---------- المجموعات (نفس بنية الأصل) ----------
  Future<String> createGroup(
      String me, String name, String photo, List<String> selected) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ref = _chats.doc();
    final members = [me, ...selected];
    final readAt = {for (final u in members) u: now};
    const text = 'تم إنشاء المجموعة';
    await ref.set({
      'type': 'group',
      'name': name,
      'photo': photo,
      'ownerId': me,
      'participants': members,
      'createdAt': now,
      'updatedAt': now,
      'readAt': readAt,
      'lastMsg': {'system': true, 'text': text, 'senderId': me, 'at': now},
    });
    await ref.collection('messages').add({
      'system': true,
      'sys': {'k': 'create', 'by': me},
      'text': text,
      'senderId': me,
      'createdAt': now,
    });
    return ref.id;
  }

  Future<void> addMembers(String chatId, String me, List<String> ids) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _chats.doc(chatId).collection('messages').add({
      'system': true,
      'sys': {'k': 'add', 'by': me, 'to': ids},
      'text': 'تمت إضافة أعضاء جدد',
      'senderId': me,
      'createdAt': now,
    });
    await _chats.doc(chatId).update({
      'participants': FieldValue.arrayUnion(ids),
      'updatedAt': now,
      for (final u in ids) 'readAt.$u': now,
      'lastMsg': {'system': true, 'text': 'تمت إضافة أعضاء جدد', 'senderId': me, 'at': now},
    });
  }

  Future<void> leaveGroup(String chatId, String me, Json meta) async {
    final rest = ((meta['participants'] as List?) ?? []).cast<String>().where((x) => x != me).toList();
    final upd = <String, dynamic>{
      'participants': FieldValue.arrayRemove([me]),
      'admins.$me': FieldValue.delete(),
    };
    if (meta['ownerId'] == me && rest.isNotEmpty) upd['ownerId'] = rest.first;
    await _chats.doc(chatId).update(upd);
  }

  Future<void> markGroupRead(String chatId, String me) => _chats
      .doc(chatId)
      .update({'readAt.$me': DateTime.now().millisecondsSinceEpoch}).catchError((_) {});

  Future<void> renameGroup(String chatId, String name) =>
      _chats.doc(chatId).update({'name': name});

  Future<void> setGroupPhoto(String chatId, String photo) =>
      _chats.doc(chatId).update({'photo': photo});

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
    String? imageDataUrl,
    String? videoUrl,
    String? posterUrl,
    String caption = '',
    int hours = 24,
    bool pinned = false,
  }) async {
    final mine = await _db.collection('stories').where('userId', isEqualTo: me).get();
    final now = DateTime.now().millisecondsSinceEpoch;
    final active = mine.docs.where((d) => ((d.data()['expiresAt'] ?? 0) as num) > now);
    if (active.length >= 3) return 'وصلت إلى الحد الأقصى: 3 قصص نشطة';
    await _db.collection('stories').add({
      'userId': me,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'imageUrl': imageDataUrl ?? posterUrl ?? '',
      'caption': caption,
      'createdAt': now,
      'expiresAt': now + hours * 3600000,
      'pinned': pinned,
    });
    final until = now + hours * 3600000;
    await _users.doc(me).set({'storyUntil': until, 'storyAt': now}, SetOptions(merge: true));
    return null;
  }

  Future<void> updateStory(String id, Json data) => _db.collection('stories').doc(id).update(data);

  /// قصص مثبتة (تبقى بعد انتهاء المدة) لمستخدم معيّن
  Future<List<Json>> pinnedStories(String uid) async {
    final q = await _db.collection('stories').where('userId', isEqualTo: uid).get();
    return q.docs.map((d) => {...d.data(), 'id': d.id}).where((s) => s['pinned'] == true).toList();
  }

  Stream<List<Json>> storyViews(String storyId) => _db
      .collection('stories')
      .doc(storyId)
      .collection('views')
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  Future<void> setStoryReaction(String storyId, String me, String? emoji) => _db
      .collection('stories')
      .doc(storyId)
      .collection('views')
      .doc(me)
      .set({'react': emoji ?? FieldValue.delete()}, SetOptions(merge: true));

  /// رد/تفاعل على قصة = رسالة بالمحادثة (storyReply:true) مثل الأصل
  Future<void> replyToStory(String me, String owner, String text, Json story) async {
    final chatId = pairChatId(me, owner);
    await _chats.doc(chatId).set({'participants': [me, owner], 'updatedAt': DateTime.now().millisecondsSinceEpoch}, SetOptions(merge: true));
    await _chats.doc(chatId).collection('messages').add({
      'senderId': me,
      'text': text,
      'storyReply': true,
      'storyReplyData': {
        'imageUrl': story['imageUrl'] ?? '',
        'videoUrl': story['videoUrl'] ?? '',
        'caption': story['caption'] ?? '',
        'storyId': story['id'] ?? '',
      },
      'read': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
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
