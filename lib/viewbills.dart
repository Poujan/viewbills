// ignore_for_file: file_names

import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pinch_zoom/pinch_zoom.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ViewBillPage extends StatefulWidget {
  final String title = "View Bills";
  const ViewBillPage({Key? key}) : super(key: key);

  @override
  State<ViewBillPage> createState() => _ViewBillPageState();
}

class _ViewBillPageState extends State<ViewBillPage> {
  bool? _downloading;
  String? _dir;
  String? _dirStorage;
  bool? permissionGranted;
  List<String>? _pdf, _tempPDF;
  final String _zipPath =
      'https://selfcareapi.telecom.mu/technical/clm/6311507/invoice-statements';
  final String _localZipFileName = 'zipFile.zip';

  getHistoryPDFList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _pdf = prefs.getStringList("PDF");
    });
  }

  void _share(BuildContext context) async {
    if (_pdf != null) {
      // ignore: deprecated_member_use
      await Share.shareFiles(
        _pdf!,
      );
    } else {}
  }

  @override
  void initState() {
    super.initState();
    _pdf = [];
    getHistoryPDFList();
    _tempPDF = [];
    _downloading = false;
    _initDir();
    _downloadZip();
    _initDirStorage();
  }

  Future _getStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      _downloadZipStorage();
      setState(() {
        permissionGranted = true;
      });
    } else if (await Permission.storage.request().isPermanentlyDenied) {
      await openAppSettings();
    } else if (await Permission.storage.request().isDenied) {
      setState(() {
        permissionGranted = false;
      });
    }
  }

  //Save in cache

  _initDir() async {
    // ignore: unnecessary_null_comparison
    if (_dir == null) {
      _dir = (await getApplicationDocumentsDirectory()).path;
      print("init $_dir");
    }
  }

  Future<File> _downloadFile(String url, String fileName) async {
    var req = await http.Client().get(Uri.parse(url));
    var file = File('$_dir/$fileName');
    print("file.path ${file.path}");
    return file.writeAsBytes(req.bodyBytes);
  }

  unarchiveAndSave(var zippedFile) async {
    var bytes = zippedFile.readAsBytesSync();
    var archive = ZipDecoder().decodeBytes(bytes);
    for (var file in archive) {
      var fileName = '$_dir/${file.name}';
      print("fileName $fileName");
      if (file.isFile && !fileName.contains("__MACOSX")) {
        var outFile = File(fileName);

        _tempPDF?.add(outFile.path);
        outFile = await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content);
      }
    }
  }

  Future<void> _downloadZip() async {
    setState(() {
      _downloading = true;
    });

    _pdf?.clear();
    _tempPDF?.clear();

    var zippedFile = await _downloadFile(_zipPath, _localZipFileName);
    await unarchiveAndSave(zippedFile);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList("pdf", _tempPDF!);
    setState(() {
      _pdf = List<String>.from(_tempPDF!);
      _downloading = false;
    });
  }

  //Save in download files

  _initDirStorage() async {
    // ignore: unnecessary_null_comparison
    if (_dirStorage == null) {
      _dirStorage = (await DownloadsPathProvider.downloadsDirectory)!.path;
      print("initStorage $_dirStorage");
    }
  }

  Future<File> _downloadFileStorage(String url, String fileNameStorage) async {
    var req = await http.Client().get(Uri.parse(url));
    var fileStorage = File('$_dirStorage/$fileNameStorage');
    print("file.path ${fileStorage.path}");
    return fileStorage.writeAsBytes(req.bodyBytes);
  }

  Future<void> _downloadZipStorage() async {
    setState(() {
      _downloading = true;
    });
    _pdf?.clear();
    _tempPDF?.clear();
    var zipfile1 = await _downloadFile(_zipPath, _localZipFileName);
    await unzipandsave(zipfile1);

    setState(() {
      _pdf = List<String>.from(_tempPDF!);
      _downloading = false;
    });
  }

  unzipandsave(var zipfile) async {
    var bytes = zipfile.readAsBytesSync();
    var inarchive = ZipDecoder().decodeBytes(bytes);
    for (var file in inarchive) {
      var fileName = '$_dirStorage/${file.name}';
      print("fileName $fileName");
      if (file.isFile && !fileName.contains("__MACOSX")) {
        var outFile = File(fileName);

        print('filename::: $outFile');
        _tempPDF?.add(outFile.path);
        outFile = await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content);
      }
    }
  }

  buildList() {
    return _pdf == null
        ? Container()
        : ListView.builder(
            itemCount: _pdf?.length,
            itemBuilder: (BuildContext context, int index) {
              return Column(
                children: [
                  Center(
                    child: Card(
                      color: Colors.white,
                      child: SizedBox(
                        width: MediaQuery.maybeOf(context)!.size.width,
                        height: 540,
                        child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: PinchZoom(
                                resetDuration:
                                    const Duration(milliseconds: 100),
                                maxScale: 2.5,
                                onZoomStart: () {
                                  print('Start zooming');
                                },
                                onZoomEnd: () {
                                  print('Stop zooming');
                                },
                                child: (PDFView(
                                  filePath: (_pdf![index]),
                                  enableSwipe: true,
                                  swipeHorizontal: true,
                                  autoSpacing: false,
                                  pageFling: true,
                                  pageSnap: true,
                                  fitPolicy: FitPolicy.BOTH,
                                )))

                            //     SfPdfViewer.file(
                            // //   File(_pdf![index]),
                            // //   // canShowScrollHead: true,
                            // // ),
                            ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
  }

  progress() {
    return Container(
      width: 25,
      height: 25,
      padding: const EdgeInsets.fromLTRB(0.0, 20.0, 10.0, 20.0),
      child: const CircularProgressIndicator(
        strokeWidth: 3.0,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              SizedBox(
                width: 400,
                height: 650,
                child: buildList(),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                        onPressed: () {
                          _getStoragePermission();
                        },
                        child: const Text("Download PDF")),
                    ElevatedButton(
                        onPressed: () {
                          _share(context);
                        },
                        child: const Text("Share PDF")),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
