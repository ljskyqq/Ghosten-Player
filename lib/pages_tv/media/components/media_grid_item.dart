import 'package:flutter/material.dart';

import '../../../components/gap.dart';
import '../../components/focusable_image.dart';

class MediaGridItem extends StatefulWidget {
  const MediaGridItem({
    super.key,
    this.onTap,
    this.imageUrl,
    this.title,
    this.subtitle,
    this.imageWidth,
    this.imageHeight,
    this.autofocus,
  });

  final String? imageUrl;
  final Widget? title;
  final Widget? subtitle;
  final double? imageWidth;
  final double? imageHeight;
  final bool? autofocus;
  final GestureTapCallback? onTap;

  @override
  State<MediaGridItem> createState() => MediaGridItemState();
}

class MediaGridItemState extends State<MediaGridItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.imageWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FocusableImage(
            autofocus: widget.autofocus,
            width: widget.imageWidth,
            height: widget.imageHeight,
            poster: widget.imageUrl,
            onTap: widget.onTap,
            onFocusChange: (f) {
              if (_focused != f) {
                setState(() => _focused = f);
              }
            },
          ),
          Gap.vSM,
          if (widget.title != null)
            DefaultTextStyle(
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(fontWeight: FontWeight.bold, color: _focused ? null : Theme.of(context).colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
              child: widget.title!,
            ),
          if (widget.subtitle != null)
            DefaultTextStyle(
              style: Theme.of(context).textTheme.labelMedium!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
              child: widget.subtitle!,
            ),
        ],
      ),
    );
  }
}
