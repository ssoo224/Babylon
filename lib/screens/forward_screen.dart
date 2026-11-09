import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar.dart';
import '../core/utils.dart';

class ForwardTarget {
  final String chatId;
  final bool group;
  ForwardTarget(this.chatId, this.group);
}

/// اختيار محادثات لإعادة توجيه الرسائل إليها
class ForwardScreen extends StatefulWidget {
  const ForwardScreen({super.key});
  @override
  State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardScreenState extends State<ForwardScreen> {
  final Map<String, ForwardTarget> _sel = {};

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ChatService>();
    final me = context.read<AuthService>().uid;
    final p = BP.of(context);
    return Scaffold(
      backgroundColor: p.chatListBg,
      appBar: AppBar(title: const Text('إعادة توجيه إلى')),
      body: StreamBuilder<List<QueryDocumentSnapshot<Json>>>(
        stream: svc.chatsStream(me),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final chats = snap.data!;
          return ListView(
            children: chats.map((c) {
              final d = c.data();
              final isG = d['type'] == 'group';
              final other = ((d['participants'] as List?) ?? []).cast<String>().firstWhere((x) => x != me, orElse: () => '');
              final sel = _sel.containsKey(c.id);
              void toggle() => setState(() => sel ? _sel.remove(c.id) : _sel[c.id] = ForwardTarget(c.id, isG));
              if (isG) {
                return CheckboxListTile(
                  value: sel,
                  onChanged: (_) => toggle(),
                  secondary: Avatar(url: d['photo'] as String?, name: (d['name'] as String?) ?? 'م'),
                  title: Text((d['name'] as String?) ?? 'مجموعة'),
                );
              }
              return FutureBuilder<Json?>(
                future: other.isEmpty ? null : svc.getUser(other),
                builder: (_, us) {
                  final u = us.data ?? {};
                  return CheckboxListTile(
                    value: sel,
                    onChanged: (_) => toggle(),
                    secondary: Avatar(url: avatarOf(u), name: (u['displayName'] as String?) ?? '?'),
                    title: Text((u['displayName'] as String?) ?? '...'),
                    subtitle: Text('@${u['username'] ?? ''}'),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: _sel.isEmpty ? null : () => Navigator.pop(context, _sel.values.toList()),
            child: Text('إرسال (${_sel.length})'),
          ),
        ),
      ),
    );
  }
}
