import 'package:api/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:readmore/readmore.dart';
import 'package:video_player/player.dart';

import '../../components/async_image.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../components/theme_builder.dart';
import 'dialogs/season_metadata.dart';
import 'episode.dart';
import 'mixins/action.dart';
import 'utils/tmdb_uri.dart';

class SeasonDetail extends StatefulWidget {
  const SeasonDetail({
    super.key,
    required this.id,
    required this.controller,
    this.themeColor,
    required this.scrapper,
  });

  final int id;
  final Scrapper scrapper;
  final int? themeColor;
  final PlayerController<TVEpisode> controller;

  @override
  State<SeasonDetail> createState() => _SeasonDetailState();
}

class _SeasonDetailState extends State<SeasonDetail> with ActionMixin<SeasonDetail>, RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext rootContext) {
    return BlocProvider(
      create: (_) => TVSeasonCubit(widget.id, null),
      child: BlocSelector<TVSeasonCubit, TVSeason?, int?>(
          selector: (season) => season?.themeColor,
          builder: (context, themeColor) {
            return ThemeBuilder(themeColor, builder: (context) {
              return Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  title: BlocBuilder<TVSeasonCubit, TVSeason?>(builder: (context, season) {
                    return season == null
                        ? const SizedBox()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${season.seriesTitle} ${season.title ?? ''}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              DefaultTextStyle(
                                style: Theme.of(context).textTheme.labelSmall!,
                                overflow: TextOverflow.ellipsis,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: AppLocalizations.of(context)!.seasonNumber(season.season), style: Theme.of(context).textTheme.bodyMedium),
                                      const WidgetSpan(child: SizedBox(width: 10)),
                                      if (season.episodeCount != null) ...[
                                        TextSpan(text: season.episodes.length.toString()),
                                        const TextSpan(text: ' / '),
                                        TextSpan(text: AppLocalizations.of(context)!.episodeCount(season.episodeCount!)),
                                      ] else
                                        TextSpan(text: AppLocalizations.of(context)!.episodeCount(season.episodes.length)),
                                      const WidgetSpan(child: SizedBox(width: 20)),
                                      if (season.airDate != null) TextSpan(text: season.airDate?.format()),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          );
                  }),
                  actions: [
                    ListTileTheme(
                        dense: true,
                        child: BlocBuilder<TVSeasonCubit, TVSeason?>(builder: (context, item) {
                          return item != null
                              ? PopupMenuButton(
                                  offset: const Offset(double.maxFinite, 0),
                                  itemBuilder: (context) => [
                                        buildWatchedAction<TVSeasonCubit, TVSeason>(context, item, MediaType.season),
                                        buildFavoriteAction<TVSeasonCubit, TVSeason>(context, item, MediaType.season),
                                        const PopupMenuDivider(),
                                        buildSkipFromStartAction<TVSeasonCubit, TVSeason>(context, item, MediaType.season, item.skipIntro),
                                        buildSkipFromEndAction<TVSeasonCubit, TVSeason>(context, item, MediaType.season, item.skipEnding),
                                        const PopupMenuDivider(),
                                        buildEditMetadataAction(context, () async {
                                          final newSeason = await showDialog<int>(context: context, builder: (context) => SeasonMetadata(season: item));
                                          if (newSeason != null) {
                                            final newId = await Api.tvSeasonNumberUpdate(item, newSeason);
                                            if (newId != item.id && context.mounted) {
                                              Navigator.pop(context);
                                            } else if (context.mounted) {
                                              context.read<TVSeasonCubit>().update();
                                            }
                                          }
                                        }),
                                        if (widget.scrapper.id != null)
                                          buildHomeAction(context, ImdbUri(MediaType.season, widget.scrapper.id!, season: item.season).toUri()),
                                        const PopupMenuDivider(),
                                        buildDeleteAction(context, () => Api.tvSeasonDeleteById(item.id)),
                                      ])
                              : const IconButton(onPressed: null, icon: Icon(null));
                        })),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                  ],
                ),
                body: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 12,
                          children: [
                            BlocSelector<TVSeasonCubit, TVSeason?, String?>(
                                selector: (season) => season?.poster,
                                builder: (context, poster) =>
                                    poster != null ? AsyncImage(poster, width: 100, radius: BorderRadius.circular(4), viewable: true) : const SizedBox()),
                            BlocSelector<TVSeasonCubit, TVSeason?, String?>(
                                selector: (season) => season?.overview,
                                builder: (context, overview) => Expanded(
                                      child: ReadMoreText(
                                        overview ?? AppLocalizations.of(context)!.noOverview,
                                        trimLines: 7,
                                        trimMode: TrimMode.Line,
                                      ),
                                    )),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverSafeArea(
                        sliver: SliverLayoutBuilder(builder: (context, constraints) {
                          final childAspectRatio = constraints.crossAxisExtent / (constraints.crossAxisExtent / 616).ceil() / 120;
                          return BlocSelector<TVSeasonCubit, TVSeason?, int?>(
                              selector: (item) => item?.episodes.length,
                              builder: (context, count) {
                                return count == null
                                    ? const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
                                    : SliverGrid.builder(
                                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 600,
                                          childAspectRatio: childAspectRatio,
                                          mainAxisSpacing: 8,
                                          crossAxisSpacing: 16,
                                        ),
                                        itemCount: count,
                                        itemBuilder: (context, index) {
                                          return BlocSelector<TVSeasonCubit, TVSeason?, TVEpisode>(
                                              selector: (item) => item!.episodes[index],
                                              builder: (context, episode) {
                                                return _EpisodeListTile(
                                                  episode: episode,
                                                  onTap: () async {
                                                    final episodes = context.read<TVSeasonCubit>().state!.episodes;
                                                    await widget.controller
                                                        .setSources(episodes.map((episode) => FromMedia.fromEpisode(episode)).toList(), index);
                                                    await widget.controller.next(index);
                                                  },
                                                  onTapMore: () async {
                                                    final box = rootContext.findRenderObject()! as RenderBox;
                                                    await showModalBottomSheet(
                                                      context: context,
                                                      barrierColor: Colors.transparent,
                                                      constraints: BoxConstraints(maxHeight: box.size.height),
                                                      isScrollControlled: true,
                                                      builder: (context) => EpisodeDetail(
                                                        tvEpisodeId: episode.id,
                                                        initialData: episode,
                                                        scrapper: widget.scrapper,
                                                      ),
                                                    );
                                                    if (context.mounted) context.read<TVSeasonCubit>().update();
                                                  },
                                                );
                                              });
                                        },
                                      );
                              });
                        }),
                      ),
                    )
                  ],
                ),
              );
            });
          }),
    );
  }
}

class _EpisodeListTile extends StatelessWidget {
  const _EpisodeListTile({
    required this.episode,
    this.onTap,
    this.onTapMore,
  });

  final TVEpisode episode;
  final GestureTapCallback? onTap;
  final GestureTapCallback? onTapMore;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (episode.poster != null)
                      AsyncImage(
                        episode.poster!,
                        radius: BorderRadius.circular(4),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(0x11), borderRadius: BorderRadius.circular(4)),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 42,
                          color: Theme.of(context).colorScheme.secondaryContainer,
                        ),
                      ),
                    Align(
                      alignment: const Alignment(0.95, 0.9),
                      child: BadgeTheme(
                        data: BadgeTheme.of(context).copyWith(
                          backgroundColor: Colors.black87,
                          textColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 10),
                        ),
                        child: IconTheme(
                          data: IconTheme.of(context).copyWith(size: 10, color: Colors.white),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (episode.watched) const Badge(label: Icon(Icons.check)),
                              if (episode.favorite) const SizedBox(width: 4),
                              if (episode.favorite) const Badge(label: Icon(Icons.favorite_rounded)),
                              if (episode.downloaded) const SizedBox(width: 4),
                              if (episode.downloaded) const Badge(label: Icon(Icons.download_rounded)),
                              if (episode.duration != null) const SizedBox(width: 4),
                              if (episode.duration != null) Badge(label: Text(episode.duration!.toDisplay())),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          Flexible(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        episode.displayTitle(),
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: onTapMore,
                      icon: const Icon(Icons.more_horiz_rounded),
                      style: IconButton.styleFrom(
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        padding: EdgeInsets.zero,
                        iconSize: 12,
                        minimumSize: const Size.square(36),
                      ),
                    ),
                  ],
                ),
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.labelSmall,
                    children: [
                      TextSpan(text: episode.seriesTitle),
                      const WidgetSpan(child: SizedBox(width: 6)),
                      TextSpan(text: AppLocalizations.of(context)!.seasonNumber(episode.season)),
                      const TextSpan(text: ' · '),
                      TextSpan(text: AppLocalizations.of(context)!.episodeNumber(episode.episode)),
                      const WidgetSpan(child: SizedBox(width: 10)),
                      if (episode.airDate != null) TextSpan(text: episode.airDate?.format() ?? AppLocalizations.of(context)!.tagUnknown),
                    ],
                  ),
                ),
                Text(
                  episode.overview ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class TVSeasonCubit extends MediaCubit<TVSeason> {
  TVSeasonCubit(this.id, super.initialState) {
    update();
  }

  final int id;

  @override
  Future<void> update() async {
    final season = await Api.tvSeasonQueryById(id);
    emit(season);
  }
}
