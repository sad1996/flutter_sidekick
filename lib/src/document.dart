import 'package:flutter/material.dart';
import 'package:flutter_youtube/flutter_youtube.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stack/src/link.dart';

class Document extends StatelessWidget {
  Document(this.url, this.type);

  final String url;
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Theme.of(context).dividerColor)),
      margin: EdgeInsets.only(top: 20),
      width: MediaQuery.of(context).size.width,
      child: type == 'link'
          ? LinkTextSpan(url: url, text: 'Click here for more info.')
          : ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CachedNetworkImage(
                      key: UniqueKey(),
                      imageUrl: _videoThumbURL(url),
                      fit: BoxFit.cover,
                    ),
                    Center(
                      child: ClipOval(
                        child: Container(
                          color: Colors.white,
                          child: IconButton(
                            iconSize: 40.0,
                            color: Colors.black,
                            icon: Icon(
                              Icons.play_arrow,
                            ),
                            onPressed: () {
                              FlutterYoutube.playYoutubeVideoByUrl(
                                  apiKey:
                                      'AIzaSyDBDzMvT95Hevkvk3y_bdZk7vn4kNqlzIc',
                                  videoUrl: url,
                                  autoPlay: true, //default falase
                                  fullScreen: true //default false
                                  );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _videoThumbURL(String yt) {
    var id = FlutterYoutube.getIdFromUrl(yt);
    return "http://img.youtube.com/vi/$id/0.jpg";
  }
}
