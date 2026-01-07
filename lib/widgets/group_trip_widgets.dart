import 'package:flutter/material.dart';
import '../config/group_trip_theme.dart';
import '../models/group_trip_model.dart';
import 'package:intl/intl.dart';

/// Professional styled card for group trip module
class StyledCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool elevated;

  const StyledCard({
    Key? key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: elevated
          ? GroupTripTheme.elevatedCardDecoration
          : GroupTripTheme.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: GroupTripTheme.mediumRadius,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(GroupTripTheme.spacingMd),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Gradient header widget
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final LinearGradient? gradient;

  const GradientHeader({
    Key? key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GroupTripTheme.spacingXl),
      decoration: BoxDecoration(
        gradient: gradient ?? GroupTripTheme.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: GroupTripTheme.spacingMd),
          Text(
            title,
            style: GroupTripTheme.headlineLarge.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: GroupTripTheme.spacingSm),
            Text(
              subtitle!,
              style: GroupTripTheme.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Role badge widget
class RoleBadge extends StatelessWidget {
  final TripRole role;
  final bool small;

  const RoleBadge({
    Key? key,
    required this.role,
    this.small = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = GroupTripTheme.getRoleColor(role.toFirestore());
    final icon = GroupTripTheme.getRoleIcon(role.toFirestore());

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 4 : 6,
      ),
      decoration: GroupTripTheme.badgeDecoration(color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: small ? 12 : 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            role.displayName.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Info box widget
class InfoBox extends StatelessWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;

  const InfoBox({
    Key? key,
    required this.title,
    required this.message,
    this.color = GroupTripTheme.primaryBlue,
    this.icon = Icons.info_outline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GroupTripTheme.spacingMd),
      decoration: GroupTripTheme.infoBoxDecoration(color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: GroupTripTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GroupTripTheme.labelLarge.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GroupTripTheme.bodySmall.copyWith(
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stat card widget
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const StatCard({
    Key? key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = GroupTripTheme.primaryBlue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GroupTripTheme.spacingMd),
      decoration: GroupTripTheme.cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: GroupTripTheme.spacingSm),
          Text(
            value,
            style: GroupTripTheme.headlineLarge.copyWith(color: color),
          ),
          const SizedBox(height: GroupTripTheme.spacingXs),
          Text(
            label,
            style: GroupTripTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Detail row widget
class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const DetailRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GroupTripTheme.spacingSm),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor ?? GroupTripTheme.primaryBlue,
          ),
          const SizedBox(width: GroupTripTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GroupTripTheme.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GroupTripTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Member avatar widget
class MemberAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;

  const MemberAvatar({
    Key? key,
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? GroupTripTheme.primaryBlue,
        shape: BoxShape.circle,
        boxShadow: GroupTripTheme.softShadow,
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}

/// Action button widget
class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool isLoading;
  final bool outlined;

  const ActionButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.isLoading = false,
    this.outlined = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? GroupTripTheme.primaryBlue;

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                ),
              )
            : Icon(icon),
        label: Text(label),
        style: GroupTripTheme.secondaryButtonStyle.copyWith(
          foregroundColor: MaterialStateProperty.all(buttonColor),
          side: MaterialStateProperty.all(
            BorderSide(color: buttonColor, width: 2),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon),
      label: Text(label),
      style: GroupTripTheme.primaryButtonStyle.copyWith(
        backgroundColor: MaterialStateProperty.all(buttonColor),
      ),
    );
  }
}

/// Activity item widget
class ActivityItem extends StatelessWidget {
  final TripActivity activity;

  const ActivityItem({
    Key? key,
    required this.activity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = GroupTripTheme.getActivityColor(activity.type.toFirestore());
    final icon = GroupTripTheme.getActivityIcon(activity.type.toFirestore());

    return StyledCard(
      padding: const EdgeInsets.all(GroupTripTheme.spacingMd),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: GroupTripTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: GroupTripTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(activity.timestamp),
                  style: GroupTripTheme.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: GroupTripTheme.smallRadius,
            ),
            child: Text(
              activity.type.displayName,
              style: GroupTripTheme.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }
}

/// Comment bubble widget
class CommentBubble extends StatelessWidget {
  final TripComment comment;
  final bool isCurrentUser;
  final VoidCallback? onDelete;

  const CommentBubble({
    Key? key,
    required this.comment,
    this.isCurrentUser = false,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      padding: const EdgeInsets.all(GroupTripTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(
                name: comment.userName,
                size: 32,
              ),
              const SizedBox(width: GroupTripTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.userName,
                          style: GroupTripTheme.labelLarge,
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  GroupTripTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: GroupTripTheme.smallRadius,
                            ),
                            child: Text(
                              'You',
                              style: GroupTripTheme.caption.copyWith(
                                color: GroupTripTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: GroupTripTheme.caption,
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  color: GroupTripTheme.errorRed,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: GroupTripTheme.spacingSm),
          Text(
            comment.comment,
            style: GroupTripTheme.bodyMedium,
          ),
          if (comment.updatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Edited',
              style: GroupTripTheme.caption.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GroupTripTheme.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: GroupTripTheme.textHint,
            ),
            const SizedBox(height: GroupTripTheme.spacingLg),
            Text(
              title,
              style: GroupTripTheme.headlineMedium.copyWith(
                color: GroupTripTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: GroupTripTheme.spacingSm),
            Text(
              message,
              style: GroupTripTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: GroupTripTheme.spacingLg),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: GroupTripTheme.primaryButtonStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading overlay widget
class LoadingOverlay extends StatelessWidget {
  final String? message;

  const LoadingOverlay({
    Key? key,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(GroupTripTheme.spacingLg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: GroupTripTheme.largeRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (message != null) ...[
                const SizedBox(height: GroupTripTheme.spacingMd),
                Text(
                  message!,
                  style: GroupTripTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header widget
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const SectionHeader({
    Key? key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: GroupTripTheme.spacingMd,
        vertical: GroupTripTheme.spacingSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GroupTripTheme.titleLarge,
          ),
          if (trailing != null)
            TextButton(
              onPressed: onTrailingTap,
              child: Text(trailing!),
              style: GroupTripTheme.textButtonStyle,
            ),
        ],
      ),
    );
  }
}
