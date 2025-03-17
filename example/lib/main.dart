import 'dart:io';

import 'package:baseflow_plugin_template/baseflow_plugin_template.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 600,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileSystem: IOFileSystem(key),
      fileService: HttpFileService(),
    ),
  );
}

void main() {
  CachedNetworkImage.logLevel = CacheManagerLogLevel.debug;

  runApp(
    MaterialApp(
      home: const GridContent(),
      // home: PageStorage(
      //   bucket: PageStorageBucket(),
      //   child: const GridContent(),
      // ),
    ),
  );
}

class NetworkImageWidget extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;
  final String? placeHolder;
  final Widget? placeHolderWidget;
  final Widget? errorWidget;
  final int fadeInDuration;
  final bool repain;
  final bool home;
  final int? index;

  const NetworkImageWidget({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.cover,
    this.placeHolder,
    this.placeHolderWidget,
    this.errorWidget,
    this.fadeInDuration = 0,
    this.repain = false,
    this.home = false,
    this.index,
  });

  @override
  State<NetworkImageWidget> createState() => _NetworkImageWidgetState();
}

class _NetworkImageWidgetState extends State<NetworkImageWidget>
    with AutomaticKeepAliveClientMixin {
  static final Map<String, CachedNetworkImageProvider> _imageProviderCache = {};
  ImageProvider? _cachedProvider;
  bool _isLoaded = false;
  bool _didInitialize = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitialize) {
      _cachedProvider = _getImageProvider(widget.url);
      _precacheImage();
      _didInitialize = true;
    }
  }

  void _precacheImage() {
    if (_cachedProvider != null) {
      precacheImage(_cachedProvider!, context).then((_) {
        if (mounted) {
          setState(() {
            _isLoaded = true;
          });
        }
      });
    }
  }

  CachedNetworkImageProvider _getImageProvider(String url) {
    // Add size parameters to the URL if they're not already present
    final Uri uri = Uri.parse(url);
    final Map<String, String> queryParams =
        Map<String, String>.from(uri.queryParameters);

    if (!queryParams.containsKey('w')) {
      queryParams['w'] = '600';
    }
    if (!queryParams.containsKey('h')) {
      queryParams['h'] = '600';
    }

    final String modifiedUrl =
        uri.replace(queryParameters: queryParams).toString();

    return _imageProviderCache.putIfAbsent(
      modifiedUrl,
      () => CachedNetworkImageProvider(
        modifiedUrl,
        cacheManager: CustomCacheManager.instance,
      ),
    );
  }

  @override
  void dispose() {
    if (widget.index != null) {
      print('Disposing NetworkImageWidget at index: ${widget.index}');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!widget.url.startsWith("http")) {
      return const SizedBox();
    }

    if (_isLoaded && _cachedProvider != null) {
      Widget imageWidget = Image(
        image: _cachedProvider!,
        width: widget.width ?? 600,
        height: widget.height ?? 600,
        fit: widget.fit,
        gaplessPlayback: true,
        isAntiAlias: true,
      );
      return widget.repain ? RepaintBoundary(child: imageWidget) : imageWidget;
    }

    // Show placeholder while loading
    return widget.placeHolderWidget ??
        (widget.placeHolder != null
            ? Image.asset(
                widget.placeHolder!,
                width: widget.width,
                height: widget.height,
              )
            : const SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ));
  }
}

/// Demonstrates a [GridView] containing [CachedNetworkImage]
class GridContent extends StatefulWidget {
  const GridContent({super.key});

  @override
  State<GridContent> createState() => _GridContentState();
}

class _GridContentState extends State<GridContent>
    with AutomaticKeepAliveClientMixin {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  final List<String> _imageUrls = List.generate(
    550,
    (index) {
      final img = imagesList[index % imagesList.length];
      if (img.endsWith('.jpg')) {
        return '$img?hahahahah=${DateTime.now()}';
      } else {
        return '$img&hahahahah=${DateTime.now()}';
      }
    },
  );

  @override
  bool get wantKeepAlive => false; // Keep this page alive

  void _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() {
      _imageUrls.shuffle();
    });
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _imageUrls.addAll(
          List.generate(
            10,
            (index) =>
                'https://loremflickr.com/100/100/music?lock=${_imageUrls.length + index}',
          ),
        );
      });
    }
    _refreshController.loadComplete();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      body: SmartRefresher(
        enablePullDown: true,
        enablePullUp: true,
        header: const WaterDropHeader(),
        footer: CustomFooter(
          builder: (context, mode) {
            Widget body;
            if (mode == LoadStatus.idle) {
              body = const Text("Pull up to load more");
            } else if (mode == LoadStatus.loading) {
              body = const CupertinoActivityIndicator();
            } else if (mode == LoadStatus.failed) {
              body = const Text("Load Failed! Click retry!");
            } else if (mode == LoadStatus.canLoading) {
              body = const Text("Release to load more");
            } else {
              body = const Text("No more Data");
            }
            return SizedBox(
              height: 55.0,
              child: Center(child: body),
            );
          },
        ),
        controller: _refreshController,
        onRefresh: _onRefresh,
        onLoading: _onLoading,
        child: ListView.builder(
          addRepaintBoundaries: true,
          addAutomaticKeepAlives: true,
          cacheExtent: 1000,
          // Cache more items
          // gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          //   crossAxisCount: 2,
          //   mainAxisSpacing: 8.0,
          //   crossAxisSpacing: 8.0,
          //   childAspectRatio: 1.0,
          // ),
          itemCount: _imageUrls.length,
          itemBuilder: (BuildContext context, int index) {
            final imgUrl = _imageUrls[index];
            return InkWell(
              /// 不会重新loading
              child: Image.network(
                imgUrl,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.width,
                // 重要：cacheWidth和cacheHeight设置之后在列表图片不会重复加载。
                cacheWidth: MediaQuery.of(context).size.width.toInt(),
                cacheHeight: MediaQuery.of(context).size.width.toInt(),
                gaplessPlayback: true,
              ),

              /// -------------------------
              /// 会重新loading
              // child: CachedNetworkImage(imageUrl:
              // imgUrl,
              //   width: 200,height: 200,
              //     useOldImageOnUrlChange: true,
              // ),
              /// -------------------------
              /// 不会重新loading，直接显示
              // child: NetworkImageWidget(
              //   url: imgUrl,
              //   index: index,
              //   width: 600,
              //   height: 600,
              // ),
              onTap: () {
                Navigator.of(context)
                    .push(CupertinoPageRoute(builder: (context) {
                  return Scaffold(
                    appBar: AppBar(),
                    body: NetworkImageWidget(
                      url: imgUrl,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  );
                }));
              },
            );
          },
        ),
      ),
    );
  }
}

const imagesList = [
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/15/61/8a/53/my-pup.jpg?w=1400&h=800&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/2e/95/59/ab/edit.jpg?w=1100&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/1b/01/bd/a3/see-two-for-the-price.jpg?w=1400&h=800&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/13/f8/5c/05/picture-lake.jpg?w=900&h=500&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/19/c2/d2/63/photo0jpg.jpg?w=1400&h=800&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/18/d7/88/98/picture-lake-5.jpg?w=1100&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/18/d7/88/62/picture-lake-4.jpg?w=1400&h=800&s=1',
  'https://media-cdn.tripadvisor.com/media/attractions-splice-spp-674x446/07/3b/f6/fc.jpg',
  'https://media-cdn.tripadvisor.com/media/attractions-splice-spp-674x446/07/3b/f6/f3.jpg',
  'https://media-cdn.tripadvisor.com/media/attractions-splice-spp-674x446/07/3b/f6/e5.jpg',
  'https://media-cdn.tripadvisor.com/media/attractions-splice-spp-674x446/0f/f6/d6/c2.jpg',
  'https://media-cdn.tripadvisor.com/media/attractions-splice-spp-674x446/0f/f6/d7/6e.jpg',
  'https://media-cdn.tripadvisor.com/media/attractions-splice-spp-674x446/0f/f6/d5/bf.jpg',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/2e/36/8a/5c/caption.jpg?w=600&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/2e/36/86/73/caption.jpg?w=600&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/2a/f5/23/1f/caption.jpg?w=600&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/2a/c1/50/41/caption.jpg?w=600&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/27/19/3e/94/caption.jpg?w=600&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/2a/f7/f3/38/caption.jpg?w=600&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/24/74/91/94/caption.jpg?w=600&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/2c/c1/03/41/caption.jpg?w=600&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/29/86/68/ef/caption.jpg?w=600&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/1c/57/fd/38/caption.jpg?w=600&h=600&s=1',
  'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/2a/17/55/4d/caption.jpg?w=600&h=600&s=1',
];
