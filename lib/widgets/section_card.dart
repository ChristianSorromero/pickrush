import 'package:flutter/material.dart';

import 'package:rider_app/app_colors.dart';
import 'package:rider_app/app_spacing.dart';
import 'package:rider_app/app_text_styles.dart';
import 'package:rider_app/widgets/surface_card.dart';

/// An overline title over a white card whose rows are split by hairlines.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Row(
            children: [
              Text(title.toUpperCase(), style: AppTextStyles.overline),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const Divider(height: 1, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Icon, label and value on one line; tappable when [onTap] is set.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.valueColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? valueColor;

  /// Defaults to a quiet grey; pass a tone color only for a state (expired...).
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            SizedBox(width: 24, child: Icon(icon, size: 22, color: iconColor ?? AppColors.textSecondary)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.caption),
                  if (value != null) ...[
                    const SizedBox(height: 1),
                    Text(value!, style: AppTextStyles.bodyStrong.copyWith(color: valueColor)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// A titled group that folds away: icon, title and a one-line summary on
/// the header (so a closed group still says what matters), rows inside.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.summary,
    this.initiallyExpanded = false,
    this.attention,
  });

  final IconData icon;
  final String title;
  final String? summary;
  final List<Widget> children;
  final bool initiallyExpanded;

  /// A tone for the header when something inside needs the rider (e.g. a
  /// document expiring); null when all is fine.
  final TaskTone? attention;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final tone = widget.attention;
    final d = AppMotion.duration(context, AppMotion.small);
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: tone == null ? AppColors.border : tone.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: '${widget.title}${widget.summary == null ? '' : ', ${widget.summary}'}',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tone?.soft ?? AppColors.surfaceMuted,
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Icon(widget.icon, size: 22, color: tone?.color ?? AppColors.textPrimary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: AppTextStyles.bodyStrong.copyWith(fontWeight: FontWeight.w800)),
                          if (widget.summary != null)
                            Text(
                              widget.summary!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: tone?.color ?? AppColors.textMuted,
                                fontWeight: tone == null ? null : FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: d,
                      curve: AppMotion.change,
                      child: const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: d,
            curve: AppMotion.change,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                    child: Column(
                      children: [
                        const Divider(height: 1, color: AppColors.border),
                        for (var i = 0; i < widget.children.length; i++) ...[
                          widget.children[i],
                          if (i < widget.children.length - 1) const Divider(height: 1, color: AppColors.divider),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
