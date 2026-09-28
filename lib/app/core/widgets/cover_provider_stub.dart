import 'package:flutter/painting.dart';

/// Web 平台不读取本地文件，一律显示占位图。
ImageProvider? localCoverProvider(String path) => null;
