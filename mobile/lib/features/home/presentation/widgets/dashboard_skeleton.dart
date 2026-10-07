import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';

/// Hand-made pulsing skeleton (no dependency).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = AppRadius.md});

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(context).skeleton;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// Placeholder mirroring the dashboard layout while the first load runs.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement du tableau de bord',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 128, radius: AppRadius.lg)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: SkeletonBox(height: 128, radius: AppRadius.lg)),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 128, radius: AppRadius.lg)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: SkeletonBox(height: 128, radius: AppRadius.lg)),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(height: 56),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 18, width: 140),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(height: 96, radius: AppRadius.lg),
          SizedBox(height: AppSpacing.lg),
          SkeletonBox(height: 18, width: 180),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(height: 200, radius: AppRadius.lg),
        ],
      ),
    );
  }
}
