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
        width: widget.width ?? 200,
        height: widget.height ?? 200,
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

    /// 图片很大，每次都会重新加载
    (index) =>
        // 'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/15/61/8a/51/picture-lake.jpg?w=1400&h=800&s=1&hahahahah=$index',
        'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/15/61/8a/51/picture-lake.jpg?w=600&h=600&s=1&hahahahah=${DateTime.now()}',

    /// 图片比较小，上下滑动和回到这个页面不会重新加载
    // 'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/15/61/8a/51/picture-lake.jpg?w=400&h=200&s=1&hahahahah=$index',
    // 'https://loremflickr.com/100/100/music?lock=$index',
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
        child: GridView.builder(
          // addRepaintBoundaries: true,
          // addAutomaticKeepAlives: true,
          // cacheExtent: 1000, // Cache more items
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            childAspectRatio: 1.0,
          ),
          itemCount: _imageUrls.length,
          itemBuilder: (BuildContext context, int index) {
            final imgUrl = _imageUrls[index];
            return InkWell(
              /// 不会重新loading
              child: Image.network(
                imgUrl,
                width: 200,
                height: 200,
                // 重要：cacheWidth和cacheHeight设置之后在列表图片不会重复加载。
                cacheWidth: 200,
                cacheHeight: 200,
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
