import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:unyo/core/enums/media_type.dart';
import 'package:unyo/domain/entities/media/anime.dart';
import 'package:unyo/domain/entities/media/manga.dart';
import 'package:unyo/domain/entities/list/media_list.dart';
import 'package:unyo/presentation/widgets/text/text_utils.dart';
import 'package:unyo/presentation/widgets/text/texts.dart';

class UnyoBannerCarousel extends StatefulWidget {
  final List<Anime>? animeList;
  final List<Manga>? mangaList;
  final void Function(Anime, MediaList)? onTapAnime;
  final void Function(Manga, MediaList)? onTapManga;

  const UnyoBannerCarousel({super.key, this.animeList, this.mangaList, this.onTapAnime, this.onTapManga});

  @override
  State<UnyoBannerCarousel> createState() => _UnyoBannerCarouselState();
}

class _UnyoBannerCarouselState extends State<UnyoBannerCarousel> {
  int _currentPage = 0;
  bool _isForward = true;
  late Timer _autoScrollTimer;
  final PageController controller = PageController(
    initialPage: 0,
    viewportFraction: 1.00,
  );

  int get _itemCount => widget.animeList?.length ?? widget.mangaList?.length ?? 0;

  @override
  void initState() {
    _startAutoScroll();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant UnyoBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItemCount = oldWidget.animeList?.length ?? oldWidget.mangaList?.length ?? 0;
    if (oldItemCount != _itemCount) {
      if (_currentPage >= _itemCount) {
        _currentPage = _itemCount == 0 ? 0 : _itemCount - 1;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) {
          controller.jumpToPage(_currentPage);
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _autoScrollTimer.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (controller.hasClients) {
        final itemCount = _itemCount;
        if (itemCount <= 1) return;

        if (_isForward) {
          if (_currentPage < itemCount - 1) {
            controller.animateToPage(
              _currentPage + 1,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            );
          } else {
            _isForward = false;
            controller.animateToPage(
              _currentPage - 1,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            );
          }
        } else {
          if (_currentPage > 0) {
            controller.animateToPage(
              _currentPage - 1,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            );
          } else {
            _isForward = true;
            controller.animateToPage(
              _currentPage + 1,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _itemCount > 0
        ? Column(
          children: [
            Container(
              width: double.infinity,
              height: 520,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
              ),
              child: PageView.builder(
                controller: controller,
                // physics: NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _itemCount,
                itemBuilder:
                    (context, index) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 50.0.r),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                if (widget.animeList != null && widget.onTapAnime != null) {
                                  widget.onTapAnime!(
                                    widget.animeList![index],
                                    const MediaListModel(name: "BannerCarousel", mediaType: MediaType.anime),
                                  );
                                } else if (widget.mangaList != null && widget.onTapManga != null) {
                                  widget.onTapManga!(
                                    widget.mangaList![index],
                                    const MediaListModel(name: "BannerCarousel", mediaType: MediaType.manga),
                                  );
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 350,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // The image
                                      Image.network(
                                        widget.animeList?[index].bannerImage ??
                                            widget.mangaList![index].bannerImage,
                                        fit: BoxFit.cover,
                                      ),

                                      // Dark overlay
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          // Adjust opacity as needed
                                          // Optional: add gradient for more dramatic effect
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(alpha: 0.8),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextTitleSmall(
                                      text:
                                          widget
                                              .animeList?[index]
                                              .title
                                              .userPreferred ??
                                          widget.mangaList![index].title.userPreferred,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      width: 50,
                                      height: 25,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            color: ColorScheme.of(context).tertiary,
                                            size: 17,
                                          ),
                                          TextLabelLarge(
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            text:
                                                widget.animeList?[index].meanScore
                                                    .toString() ??
                                                widget.mangaList![index].meanScore
                                                    .toString(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextBodyMedium(
                                        text:
                                            TextUtils.parseHtmlToPlainText(widget.animeList?[index].description ??
                                            widget.mangaList![index].description),
                                        maxLines: 6,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _itemCount,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: _currentPage == index ? 8 : 6,
                  // Make current one larger
                  width: _currentPage == index ? 8 : 6,
                  // Make current one larger
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, // Make them circular
                    color:
                        _currentPage == index
                            ? ColorScheme.of(context).tertiary
                            : Colors.grey.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ],
        )
        : const SizedBox.shrink();
  }
}
