import 'dart:math' as math;
import 'dart:ui' as ui show Image;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ImageShow extends StatefulWidget {
  final String imageUrl;

  ImageShow(
    this.imageUrl, {
    Key key,
    @deprecated double scale,
  }) : super(key: key);

  @override
  _ImageShowState createState() => new _ImageShowState();
}

class _ImageShowState extends State<ImageShow> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Hero(
        tag: widget.imageUrl,
        transitionOnUserGestures: true,
        child: CachedNetworkImage(
          errorWidget: (context, url, error) => Icon(
            Icons.error,
          ),
          fit: BoxFit.cover,
          imageUrl: widget.imageUrl,
        ),
      ),
      onTap: () {
        pushFullScreenWidget();
      },
    );
  }

  Widget fullScreenRoutePageBuilder(BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation) {
    return _buildFullScreenImage();
  }

  void pushFullScreenWidget() {
    final TransitionRoute<void> route = PageRouteBuilder<void>(
      settings: RouteSettings(isInitialRoute: false),
      pageBuilder: fullScreenRoutePageBuilder,
    );
    Navigator.of(context).push(route);
  }

  Widget _buildFullScreenImage() {
    return Material(
      child: Center(
        child: GestureDetector(
          child: Hero(
            tag: widget.imageUrl,
            transitionOnUserGestures: true,
            child: ZoomableImage(
              widget.imageUrl,
              backgroundColor: Theme.of(context).canvasColor,
            ),
            flightShuttleBuilder:
                (flightContext, animation, direction, fromContext, toContext) {
              return CachedNetworkImage(
                errorWidget: (context, url, error) => Icon(
                  Icons.error,
                ),
                fit: BoxFit.fitWidth,
                imageUrl: widget.imageUrl,
              );
            },
          ),
          onTap: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class ZoomableImage extends StatefulWidget {
  final String imageUrl;
  final double maxScale;
  final double minScale;
  final Color backgroundColor;
  final Widget placeholder;

  ZoomableImage(
    this.imageUrl, {
    Key key,
    @deprecated double scale,
    this.maxScale = 2.0,
    this.minScale = 0.5,
    this.backgroundColor = Colors.black,
    this.placeholder,
  }) : super(key: key);

  @override
  _ZoomableImageState createState() => new _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  ImageProvider _baseImage;
  ImageStream _imageStream;
  ImageStreamListener _listenerStream;
  ui.Image _image;
  Size _imageSize;

  Offset _startingFocalPoint;

  Offset _previousOffset;
  Offset _offset;

  double _previousScale;
  double _scale;

  Orientation _previousOrientation;

  Size _canvasSize;

  void _centerAndScaleImage() {
    _imageSize = new Size(
      _image.width.toDouble(),
      _image.height.toDouble(),
    );

    _scale = math.min(
      _canvasSize.width / _imageSize.width,
      _canvasSize.height / _imageSize.height,
    );
    Size fitted = new Size(
      _imageSize.width * _scale,
      _imageSize.height * _scale,
    );

    Offset delta = _canvasSize - fitted;
    _offset = delta / 2.0;
  }

  Function() _handleDoubleTap(BuildContext ctx) {
    return () {
      double newScale = _scale * 2;
      if (newScale > widget.maxScale) {
        _centerAndScaleImage();
        setState(() {});
        return;
      }

      Offset center = ctx.size.center(Offset.zero);
      Offset newOffset = _offset - (center - _offset);

      setState(() {
        _scale = newScale;
        _offset = newOffset;
      });
    };
  }

  void _handleScaleStart(ScaleStartDetails d) {
    _startingFocalPoint = d.focalPoint;
    _previousOffset = _offset;
    _previousScale = _scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails d) {
    double newScale = _previousScale * d.scale;
    if (newScale > widget.maxScale || newScale < widget.minScale) {
      return;
    }

    final Offset normalizedOffset =
        (_startingFocalPoint - _previousOffset) / _previousScale;
    final Offset newOffset = d.focalPoint - normalizedOffset * newScale;

    setState(() {
      _scale = newScale;
      _offset = newOffset;
    });
  }

  @override
  Widget build(BuildContext ctx) {
    Widget paintWidget() {
      return new CustomPaint(
        child: new Container(color: widget.backgroundColor),
        foregroundPainter: new _ZoomableImagePainter(
          image: _image,
          offset: _offset,
          scale: _scale,
        ),
      );
    }

    if (_image == null) {
      return widget.placeholder ?? Center(child: CircularProgressIndicator());
    }

    return new LayoutBuilder(builder: (ctx, constraints) {
      Orientation orientation = MediaQuery.of(ctx).orientation;
      if (orientation != _previousOrientation) {
        _previousOrientation = orientation;
        _canvasSize = constraints.biggest;
        _centerAndScaleImage();
      }

      return new GestureDetector(
        child: paintWidget(),
        onDoubleTap: _handleDoubleTap(ctx),
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
      );
    });
  }

  @override
  void didChangeDependencies() {
    _resolveImage();
    super.didChangeDependencies();
  }

  @override
  void reassemble() {
    _resolveImage(); // in case the image cache was flushed
    super.reassemble();
  }

  void _resolveImage() {
    _baseImage = CachedNetworkImageProvider(
      widget.imageUrl,
    );
    _imageStream = _baseImage.resolve(createLocalImageConfiguration(context));
    _listenerStream = ImageStreamListener(_handleImageLoaded);
    _imageStream.addListener(_listenerStream);
  }

  void _handleImageLoaded(ImageInfo info, bool synchronousCall) {
    setState(() {
      _image = info.image;
    });
  }

  @override
  void dispose() {
    _imageStream.removeListener(_listenerStream);
    super.dispose();
  }
}

class _ZoomableImagePainter extends CustomPainter {
  const _ZoomableImagePainter({this.image, this.offset, this.scale});

  final ui.Image image;
  final Offset offset;
  final double scale;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    Size imageSize = new Size(image.width.toDouble(), image.height.toDouble());
    Size targetSize = imageSize * scale;

    paintImage(
      canvas: canvas,
      rect: offset & targetSize,
      image: image,
      fit: BoxFit.cover,
    );
  }

  @override
  bool shouldRepaint(_ZoomableImagePainter old) {
    return old.image != image || old.offset != offset || old.scale != scale;
  }
}
