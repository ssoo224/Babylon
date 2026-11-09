import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/chat_service.dart';
import '../widgets/avatar.dart';

class OtherProfileScreen extends StatelessWidget {
  final String uid;
  const OtherProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BP.of(context).chatListBg,
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: StreamBuilder<Json?>(
        stream: context.read<ChatService>().userStream(uid),
        builder: (context, s) {
          final u = s.data;
          if (u == null) return const Center(child: CircularProgressIndicator());
          final name = (u['displayName'] as String?) ?? '';
          return ListView(padding: const EdgeInsets.all(24), children: [
            Center(
              child: GestureDetector(
                onTap: () {
                  final img = imageFromUrl(u['avatarUrl']);
                  if (img == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white),
                        body: Center(child: InteractiveViewer(child: Image(image: img))),
                      ),
                    ),
                  );
                },
                child: Avatar(url: u['avatarUrl'], name: name, size: 120),
              ),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (u['isVerified'] == true)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.verified, color: Theme.of(context).colorScheme.primary),
                ),
            ]),
            Center(child: Text('@${u['username'] ?? ''}', textDirection: TextDirection.ltr)),
            const SizedBox(height: 6),
            Center(child: Text(formatLastSeen(u), style: const TextStyle(fontSize: 12))),
            if ((u['bio'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(u['bio']))),
            ],
          ]);
        },
      ),
    );
  }
}
