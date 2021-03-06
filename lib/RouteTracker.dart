import 'package:flutter/material.dart';
import 'dart:math';
import 'MyLocation.dart';
import 'PlatformLevelLocationIssueHandler.dart';
import 'NewRouteStarterAndSaver.dart';
import 'StoredRouteDisplayer.dart';
import 'dart:async';

class RouteTrackerHome extends StatefulWidget {
  final MyLocation location;
  final PlatformLevelLocationIssueHandler platformLevelLocationIssueHandler;

  RouteTrackerHome(
      {Key key,
      @required this.location,
      @required this.platformLevelLocationIssueHandler})
      : super(key: key);

  @override
  _RouteTrackerHome createState() => _RouteTrackerHome();
}

class _RouteTrackerHome extends State<RouteTrackerHome> {
  Future<Map<String, List<Map<String, String>>>> myRoutes;
  int routeCount = 0;

  @override
  void initState() {
    super.initState();
    myRoutes = getRoutes();
    myRoutes.then((Map<String, List<Map<String, String>>> val) {
      setState(() {
        routeCount = val.keys.toList().length;
      });
    });
  }

  int parseTimeStamp(String timeStamp) {
    List<String> tmp = timeStamp.split(' ');
    DateTime myDateTime;
    try {
      myDateTime = DateTime(
          int.parse(tmp[0].split('/')[2]),
          int.parse(tmp[0].split('/')[1]),
          int.parse(tmp[0].split('/')[0]),
          int.parse(tmp[1].split(':')[0]),
          int.parse(tmp[1].split(':')[1]),
          int.parse(tmp[1].split(':')[2]));
    } catch (e) {
      myDateTime = DateTime.now();
    }
    return myDateTime.millisecondsSinceEpoch;
  }

  Map<String, String> getFinalPoint(List<Map<String, String>> points) {
    int maxTime = 0;
    Map<String, String> finalPoint = {};
    points.forEach((Map<String, String> elem) {
      int tmp = parseTimeStamp(elem["timeStamp"]);
      if (tmp > maxTime) {
        maxTime = tmp;
        finalPoint = elem;
      }
    });
    return finalPoint;
  }

  Map<String, String> getInitPoint(List<Map<String, String>> points) {
    int minTime = parseTimeStamp(points[0]["timeStamp"]);
    Map<String, String> initPoint = points[0];
    points.forEach((Map<String, String> elem) {
      int tmp = parseTimeStamp(elem["timeStamp"]);
      if (tmp < minTime) {
        minTime = tmp;
        initPoint = elem;
      }
    });
    return initPoint;
  }

  int getRouteDuration(List<Map<String, String>> points) {
    return parseTimeStamp(getFinalPoint(points)["timeStamp"]) -
        parseTimeStamp(getInitPoint(points)["timeStamp"]);
  }

  double getRouteDistance(List<Map<String, String>> points) {
    double sum = 0.0;
    for (int i = 1; i < points.length; i++) {
      List<double> point1 = [
        double.parse(points[i - 1]["longitude"]),
        double.parse(points[i - 1]["latitude"])
      ];
      List<double> point2 = [
        double.parse(points[i]["longitude"]),
        double.parse(points[i]["latitude"])
      ];
      sum +=
          ((acos(sin((point1[1] * pi) / 180.0) * sin((point2[1] * pi) / 180.0) +
                          cos((point1[1] * pi) / 180.0) *
                              cos((point2[1] * pi) / 180.0) *
                              cos(((point1[0] - point2[0]) * pi) / 180.0)) *
                      180.0) /
                  pi) *
              60 *
              1.1515 *
              1.609344;
    }
    return sum;
  }

  Future<Map<String, List<Map<String, String>>>> getRoutes() async {
    return await widget.platformLevelLocationIssueHandler.methodChannel
        .invokeMethod("getRoutes")
        .then((dynamic value) {
      return extractValues(value);
    });
  }

  Map<String, List<Map<String, String>>> extractValues(dynamic value) {
    List<dynamic> tmpValues = List<dynamic>.from(value);
    List<Map<String, String>> allRoutes = [];
    tmpValues.forEach((dynamic elem) {
      allRoutes.add({
        "longitude": elem["longitude"],
        "latitude": elem["latitude"],
        "timeStamp": elem["timeStamp"],
        "altitude": elem["altitude"],
        "routeId": elem["routeId"]
      });
    });
    List<String> routeIds = [];
    Map<String, List<Map<String, String>>> processedRoutes = {};
    allRoutes.forEach((Map<String, String> elem) {
      if (!routeIds.contains(elem["routeId"])) {
        processedRoutes[elem["routeId"]] = [
          {
            "longitude": elem["longitude"],
            "latitude": elem["latitude"],
            "timeStamp": elem["timeStamp"],
            "altitude": elem["altitude"]
          }
        ];
        routeIds.add(elem["routeId"]);
      } else {
        processedRoutes[elem["routeId"]].add({
          "longitude": elem["longitude"],
          "latitude": elem["latitude"],
          "timeStamp": elem["timeStamp"],
          "altitude": elem["altitude"]
        });
      }
    });
    return processedRoutes;
  }

  String getTimeSpentOnRoute(int duration) {
    String text = '';
    if (duration > 60) {
      if (duration > 3600) {
        if (duration > 3600 * 24) {
          if (duration > 3600 * 24 * 7) {
            if (duration > 3600 * 24 * 7 * 52)
              text =
                  '${duration ~/ 31449600}y ${(duration % 31449600) ~/ 604800}w ${((duration % 31449600) % 604800) ~/ 86400}d ${(((duration % 31449600) % 604800) % 86400) ~/ 3600}h ${((((duration % 31449600) % 604800) % 86400) % 3600) ~/ 60}m ${((((duration % 31449600) % 604800) % 86400) % 3600) % 60}s';
            else
              text =
                  '${duration ~/ 604800}w ${(duration % 604800) ~/ 86400}d ${((duration % 604800) % 86400) ~/ 3600}h ${(((duration % 604800) % 86400) % 3600) ~/ 60}m ${(((duration % 604800) % 86400) % 3600) % 60}s';
          } else
            text =
                '${duration ~/ 86400}d ${(duration % 86400) ~/ 3600}h ${((duration % 86400) % 3600) ~/ 60}m ${((duration % 86400) % 3600) % 60}s';
        } else
          text =
              '${duration ~/ 3600}h ${(duration % 3600) ~/ 60}m ${(duration % 3600) % 60}s';
      } else
        text = '${duration ~/ 60}m ${duration % 60}s';
    } else
      text = '${duration}s';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Route Tracker',
          style: TextStyle(color: Colors.black87),
        ),
        elevation: 8,
        backgroundColor: Colors.cyanAccent,
        actions: <Widget>[
          Builder(
            builder: (BuildContext ctx) {
              return IconButton(
                icon: Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
                onPressed: routeCount != 0
                    ? () {
                        showDialog(
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("Clear Records"),
                              elevation: 14.0,
                              content: Text(
                                "Do you want me to clear all Saved Routes ?",
                              ),
                              actions: <Widget>[
                                RaisedButton(
                                  child: Text(
                                    "Yes",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  color: Colors.tealAccent,
                                ),
                                RaisedButton(
                                  child: Text(
                                    "No",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  color: Colors.tealAccent,
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                ),
                              ],
                            );
                          },
                          context: context,
                        ).then((dynamic value) async {
                          if (value == true) {
                            await widget
                                .platformLevelLocationIssueHandler.methodChannel
                                .invokeMethod("clearRoutes")
                                .then((dynamic val) {
                              if (val == 1) {
                                Scaffold.of(ctx).showSnackBar(SnackBar(
                                  content: Text(
                                    "Cleared all Routes",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  duration: Duration(seconds: 1),
                                  backgroundColor: Colors.cyanAccent,
                                ));
                                setState(() {
                                  myRoutes = getRoutes();
                                  myRoutes.then(
                                      (Map<String, List<Map<String, String>>>
                                          val) {
                                    routeCount = val.keys.toList().length;
                                  });
                                });
                              }
                            });
                          }
                        });
                      }
                    : () {
                        Scaffold.of(ctx).showSnackBar(SnackBar(
                          content: Text(
                            "Nothing to Clear",
                            style: TextStyle(color: Colors.white),
                          ),
                          duration: Duration(seconds: 1),
                          backgroundColor: Colors.redAccent,
                        ));
                      },
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, List<Map<String, String>>>>(
        future: myRoutes,
        builder: (BuildContext context,
            AsyncSnapshot<Map<String, List<Map<String, String>>>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.sentiment_dissatisfied,
                      size: 150,
                      color: Colors.cyanAccent,
                    ),
                    Text("No routes saved yet :/"),
                  ],
                ),
              );
            case ConnectionState.active:
            case ConnectionState.waiting:
              return Center(
                child: CircularProgressIndicator(
                  backgroundColor: Colors.cyanAccent,
                ),
              );
            case ConnectionState.done:
              if (snapshot.data == null || snapshot.data.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.sentiment_dissatisfied,
                        size: 150,
                        color: Colors.cyanAccent,
                      ),
                      Text("No routes saved yet :/"),
                    ],
                  ),
                );
              } else {
                List<String> routeIds = snapshot.data.keys.toList();
                routeCount = routeIds.length;
                return ListView.builder(
                  itemBuilder: (BuildContext context, int index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (BuildContext context) =>
                                DisplayStoredRoute(
                                  routeId: routeIds[index],
                                  duration: getTimeSpentOnRoute(
                                      getRouteDuration(
                                              snapshot.data[routeIds[index]]) ~/
                                          1000),
                                  distance: getRouteDistance(
                                      snapshot.data[routeIds[index]]),
                                  startTime: getInitPoint(snapshot
                                      .data[routeIds[index]])["timeStamp"],
                                  endTime: getFinalPoint(snapshot
                                      .data[routeIds[index]])["timeStamp"],
                                  myRoute: snapshot.data[routeIds[index]],
                                  platformLevelLocationIssueHandler:
                                      widget.platformLevelLocationIssueHandler,
                                )));
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                            left: 4.0, right: 4.0, top: 6.0, bottom: 6.0),
                        padding: EdgeInsets.only(
                            left: 14.0, right: 14.0, top: 10.0, bottom: 10.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Colors.cyanAccent, Colors.tealAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'RouteId // ',
                                  style: TextStyle(
                                    letterSpacing: 3.0,
                                  ),
                                ),
                                Text(
                                  '${routeIds[index]}',
                                ),
                              ],
                            ),
                            Container(
                              margin: EdgeInsets.all(8.0),
                              padding: EdgeInsets.only(
                                  left: 12.0,
                                  right: 12.0,
                                  top: 8.0,
                                  bottom: 8.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                        'Started at',
                                      ),
                                      Text(
                                        '${getInitPoint(snapshot.data[routeIds[index]])["timeStamp"]}',
                                      ),
                                    ],
                                  ),
                                  Divider(
                                    height: 6,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                        'Finished at',
                                      ),
                                      Text(
                                        '${getFinalPoint(snapshot.data[routeIds[index]])["timeStamp"]}',
                                      ),
                                    ],
                                  ),
                                  Divider(
                                    height: 6,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                        'Duration',
                                      ),
                                      Text(
                                        '${getTimeSpentOnRoute(getRouteDuration(snapshot.data[routeIds[index]]) ~/ 1000)}',
                                      ),
                                    ],
                                  ),
                                  Divider(
                                    height: 6,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                        '# of Data Points over Route',
                                      ),
                                      Text(
                                        '${snapshot.data[routeIds[index]].length}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  itemCount: routeIds.length,
                  padding:
                      EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8),
                );
              }
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(
            builder: (BuildContext context) => NewRouteStarterAndSaver(
                location: widget.location,
                platformLevelLocationIssueHandler:
                    widget.platformLevelLocationIssueHandler),
          ))
              .then((dynamic value) {
            setState(() {
              myRoutes = getRoutes();
              myRoutes.then((Map<String, List<Map<String, String>>> val) {
                routeCount = val.keys.toList().length;
              });
            });
          });
        },
        backgroundColor: Colors.cyanAccent,
        highlightElevation: 8.0,
        tooltip: 'Start a new Route',
        child: Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}
