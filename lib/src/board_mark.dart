import 'package:flutter/material.dart';
import 'constants.dart';

class BoardMark {
  final Color color;

  BoardMark({
    //required this.square,
    Color? color,
  })  : /*assert(square.length == 2),
        assert(squareRegex.hasMatch(square)),*/
        this.color = color ?? Colors.red.withOpacity(0.5);

  /*@override
  bool operator ==(Object other) {
    return other is BoardMark &&
        square == other.square;
  }

  @override
  int get hashCode => square.hashCode;*/
}
