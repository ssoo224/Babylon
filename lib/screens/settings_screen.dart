import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final auth = context.read<AuthService>();
    return Scaffold(
      backgroundColor: BP.of(context).chatListBg,
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('المظهر', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        RadioListTile<ThemeMode>(
          value: ThemeMode.dark,
          groupValue: theme.mode,
          title: const Text('داكن'),
          onChanged: (v) => theme.set(v!),
        ),
        RadioListTile<ThemeMode>(
          value: ThemeMode.light,
          groupValue: theme.mode,
          title: const Text('فاتح'),
          onChanged: (v) => theme.set(v!),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.block),
          title: const Text('المستخدمون المحظورون'),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const _BlockedScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent)),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('تسجيل الخروج'),
                content: const Text('هل تريد تسجيل الخروج؟'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('خروج')),
                ],
              ),
            );
            if (ok == true) auth.logout();
          },
        ),
      ]),
    );
  }
}

class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen();

  @override
  Widget build(BuildContext context) {
    final svc = context.read<ChatService>();
    final me = context.read<AuthService>().uid;
    return Scaffold(
      appBar: AppBar(title: const Text('المحظورون')),
      body: StreamBuilder<Set<String>>(
        stream: svc.blocks(me),
        builder: (context, s) {
          final ids = (s.data ?? {}).toList();
          if (ids.isEmpty) return const Center(child: Text('لا يوجد مستخدمون محظورون'));
          return ListView(
            children: ids
                .map((id) => FutureBuilder<Json?>(
                      future: svc.getUser(id),
                      builder: (_, us) {
                        final u = us.data ?? {};
                        return ListTile(
                          leading: Avatar(url: u['avatarUrl'], name: u['displayName'] ?? '?'),
                          title: Text(u['displayName'] ?? id),
                          subtitle: Text('@${u['username'] ?? ''}'),
                          trailing: TextButton(
                            onPressed: () => svc.unblock(me, id),
                            child: const Text('إلغاء الحظر'),
                          ),
                        );
                      },
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}
