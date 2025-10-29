import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_service.dart';

class OnlineIndicator extends StatelessWidget {
  final double size;
  final bool showBorder;
  final Color? borderColor;

  const OnlineIndicator({
    Key? key,
    this.size = 12.0,
    this.showBorder = true,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionService>(
      builder: (context, connectionService, child) {
        final isOnline = connectionService.isUserOnline;
        final color = isOnline 
          ? const Color(ConnectionService.onlineColor)
          : const Color(ConnectionService.offlineColor);

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: showBorder
              ? Border.all(
                  color: borderColor ?? Colors.white,
                  width: 2.0,
                )
              : null,
          ),
        );
      },
    );
  }
}

class OnlineStatusText extends StatelessWidget {
  final TextStyle? style;

  const OnlineStatusText({
    Key? key,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionService>(
      builder: (context, connectionService, child) {
        final isOnline = connectionService.isUserOnline;
        final text = isOnline ? 'Online' : 'Offline';
        final color = isOnline 
          ? const Color(ConnectionService.onlineColor)
          : const Color(ConnectionService.offlineColor);

        return Text(
          text,
          style: (style ?? const TextStyle()).copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }
}
