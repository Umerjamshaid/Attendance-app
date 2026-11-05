import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider<Object> profileImageProvider(String path) =>
    path.startsWith('https://') ? NetworkImage(path) : FileImage(File(path));
