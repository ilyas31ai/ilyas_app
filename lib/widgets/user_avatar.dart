import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class UserAvatar extends StatelessWidget {
  final String username;
  final double radius;
  final bool showStatus;

  const UserAvatar({
    super.key,
    required this.username,
    this.radius = 22,
    this.showStatus = false,
  });

  static const _palette = [
    Color(0xFF2563EB),
    Color(0xFF6C47FF),
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
    Color(0xFFBE185D),
    Color(0xFF15803D),
    Color(0xFF7C3AED),
    Color(0xFF0F766E),
  ];

  Color get _color {
    if (username.isEmpty) return _palette[0];
    int hash = 0;
    for (final c in username.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return _palette[hash % _palette.length];
  }

  String get _initials {
    if (username.isEmpty) return '?';
    final name =
        username.contains('@') ? username.split('@').first : username;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.65,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    if (!showStatus) return circle;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          bottom: 0,
          right: 0,
          child: _StatusDot(username: username),
        ),
      ],
    );
  }
}

// ─── Status Dot ───────────────────────────────────────────────────────────────
// StatefulWidget : stream stocké en initState → une seule souscription stable

class _StatusDot extends StatefulWidget {
  final String username;
  const _StatusDot({required this.username});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> {
  late final Stream<DatabaseEvent> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseDatabase.instance
        .ref('status/${widget.username}/online')
        .onValue;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _stream,
      builder: (context, snap) {
        final online =
            snap.hasData && snap.data?.snapshot.value == true;
        return Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: online ? Colors.greenAccent : const Color(0xFF4B5563),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF0D1117),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

// ─── Online Label ─────────────────────────────────────────────────────────────
// StatefulWidget : stream stocké en initState → une seule souscription stable

class OnlineLabel extends StatefulWidget {
  final String username;
  const OnlineLabel({super.key, required this.username});

  @override
  State<OnlineLabel> createState() => _OnlineLabelState();
}

class _OnlineLabelState extends State<OnlineLabel> {
  late final Stream<DatabaseEvent> _stream;

  @override
  void initState() {
    super.initState();
    _stream =
        FirebaseDatabase.instance.ref('status/${widget.username}').onValue;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _stream,
      builder: (context, snap) {
        bool online = false;
        if (snap.hasData && snap.data!.snapshot.value != null) {
          final d = Map<dynamic, dynamic>.from(
              snap.data!.snapshot.value as Map);
          online = d['online'] == true;
        }
        return Text(
          online ? 'En ligne' : 'Hors ligne',
          style: TextStyle(
            color: online ? Colors.greenAccent : Colors.white38,
            fontSize: 11,
          ),
        );
      },
    );
  }
}
