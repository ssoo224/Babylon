import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();
  Json? _result;
  bool _loading = false;
  bool _searched = false;

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    final r = await context.read<ChatService>().findByUsername(_c.text);
    if (mounted) {
      setState(() {
        _result = r;
        _loading = false;
      });
    }
  }

  Future<void> _open(Json u) async {
    final me = context.read<AuthService>().uid;
    final other = u['id'] as String;
    if (other == me) return;
    final id = await context.read<ChatService>().ensureChat(me, other);
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherId: other)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _c,
          autofocus: true,
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
              hintText: 'ابحث بيوزر المستخدم', prefixText: '@'),
        ),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: _search)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? const Center(child: Text('اكتب يوزر المستخدم بالضبط'))
              : _result == null
                  ? const Center(child: Text('لا يوجد مستخدم بهذا اليوزر'))
                  : ListTile(
                      leading: Avatar(
                          url: avatarOf(_result),
                          name: _result!['displayName'] ?? ''),
                      title: Text(_result!['displayName'] ?? ''),
                      subtitle: Text('@${_result!['username'] ?? ''}'),
                      onTap: () => _open(_result!),
                    ),
    );
  }
}
