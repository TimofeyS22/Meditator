import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:meditator/app/theme.dart';

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key, required this.child});
  final Widget child;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (offline != _offline && mounted) {
        setState(() => _offline = offline);
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (offline != _offline && mounted) {
      setState(() => _offline = offline);
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _offline ? (MediaQuery.paddingOf(context).top + 28) : 0,
          color: C.error.withValues(alpha: 0.9),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 4),
          child: _offline
              ? Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Нет подключения к интернету',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : null,
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
