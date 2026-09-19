import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class UserAvatarWidget extends StatelessWidget {
  final String? avatarPath;
  final double size;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;

  const UserAvatarWidget({
    super.key,
    this.avatarPath,
    this.size = 40,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatarContent;
    final path = (avatarPath ?? '').trim();

    if (path.startsWith('http://') || path.startsWith('https://')) {
      avatarContent = Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Center(
              child: SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _fallbackWidget(),
      );
    } else if (path.isNotEmpty && !path.startsWith('assets/')) {
      // Local file path
      final file = File(path);
      if (file.existsSync()) {
        avatarContent = Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackWidget(),
        );
      } else {
        avatarContent = _fallbackWidget();
      }
    } else if (path.startsWith('assets/')) {
      avatarContent = Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackWidget(),
      );
    } else {
      avatarContent = _fallbackWidget();
    }

    Widget container = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: borderColor ?? AppColors.primary,
                width: 2,
              )
            : null,
      ),
      child: ClipOval(child: avatarContent),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }

  Widget _fallbackWidget() {
    return Container(
      width: size,
      height: size,
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          Icons.person,
          size: size * 0.6,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
