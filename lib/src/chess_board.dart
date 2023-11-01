import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' hide State;
import 'package:flutter_chess_board/src/board_mark.dart';
import 'package:flutter_chess_board/src/symbols.dart';
import 'package:flutter_svg/svg.dart';
import 'board_arrow.dart';
import 'chess_board_controller.dart';
import 'constants.dart';

class ChessBoard extends StatefulWidget {
  /// An instance of [ChessBoardController] which holds the game and allows
  /// manipulating the board programmatically.
  final ChessBoardController controller;

  /// Size of chessboard
  final double? size;

  /// A boolean which checks if the user should be allowed to make moves
  final bool enableUserMoves;

  /// The color type of the board
  final BoardColor boardColor;

  final PlayerColor boardOrientation;

  final VoidCallback? onMove;
  final void Function(String square)? onMark;

  final List<BoardArrow> arrows;
  final Map<String, BoardMark> marks;

  const ChessBoard({
    Key? key,
    required this.controller,
    this.size,
    this.enableUserMoves = true,
    this.boardColor = BoardColor.brown,
    this.boardOrientation = PlayerColor.white,
    this.onMove,
    this.onMark,
    this.arrows = const [],
    this.marks = const {},
  }) : super(key: key);

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Chess>(
      valueListenable: widget.controller,
      builder: (context, game, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              AspectRatio(
                child: _getBoardImage(widget.boardColor),
                aspectRatio: 1.0,
              ),
              if (widget.marks.isNotEmpty)
                IgnorePointer(
                    child: AspectRatio(
                  aspectRatio: 1.0,
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8),
                    itemBuilder: (context, index) {
                      var row = index ~/ 8;
                      var column = index % 8;
                      var boardRank =
                          widget.boardOrientation == PlayerColor.black
                              ? '${row + 1}'
                              : '${(7 - row) + 1}';
                      var boardFile =
                          widget.boardOrientation == PlayerColor.white
                              ? '${files[column]}'
                              : '${files[7 - column]}';

                      var squareName = '$boardFile$boardRank';
                      var mark = widget.marks[squareName];
                      return mark != null
                          ? Container(
                              color: mark.color,
                            )
                          : Container();
                    },
                    itemCount: 64,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                  ),
                )),
              AspectRatio(
                aspectRatio: 1.0,
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8),
                  itemBuilder: (context, index) {
                    var row = index ~/ 8;
                    var column = index % 8;
                    var boardRank = widget.boardOrientation == PlayerColor.black
                        ? '${row + 1}'
                        : '${(7 - row) + 1}';
                    var boardFile = widget.boardOrientation == PlayerColor.white
                        ? '${files[column]}'
                        : '${files[7 - column]}';

                    var squareName = '$boardFile$boardRank';
                    var pieceOnSquare = game.get(squareName);

                    var piece = BoardPiece(
                      squareName: squareName,
                      game: game,
                    );

                    var mate = pieceOnSquare?.type == PieceType.KING &&
                        game.in_checkmate &&
                        game.king_attacked(pieceOnSquare!.color);

                    var stalemate = pieceOnSquare?.type == PieceType.KING &&
                        game.in_stalemate;
                    var insufficientMaterial =
                        pieceOnSquare?.type == PieceType.KING &&
                            game.insufficient_material;
                    var threefoldRepetition =
                        pieceOnSquare?.type == PieceType.KING &&
                            game.in_threefold_repetition;

                    var draggable = game.get(squareName) != null
                        ? Draggable<PieceMoveData>(
                            onDragStarted: () {},
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                piece,
                                if (mate)
                                  mateSymbol()
                                else if (stalemate)
                                  drawSymbol()
                                else if (insufficientMaterial)
                                  insufficientMaterialSymbol()
                                else if (threefoldRepetition)
                                  threefoldRepetitionSymbol()
                              ],
                            ),
                            feedback: Container(
                              child: piece,
                              height:
                                  widget.size != null ? widget.size! / 8 : null,
                              width:
                                  widget.size != null ? widget.size! / 8 : null,
                            ),
                            childWhenDragging: SizedBox(),
                            data: PieceMoveData(
                              squareName: squareName,
                              pieceType:
                                  pieceOnSquare?.type.toUpperCase() ?? 'P',
                              pieceColor: pieceOnSquare?.color ?? Color.WHITE,
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(),
                          );

                    var dragTarget =
                        DragTarget<PieceMoveData>(builder: (context, list, _) {
                      return draggable;
                    }, onWillAccept: (pieceMoveData) {
                      return (widget.enableUserMoves ? true : false) &&
                          !game.in_checkmate &&
                          !stalemate &&
                          !insufficientMaterial &&
                          !threefoldRepetition;
                    }, onAccept: (PieceMoveData pieceMoveData) async {
                      // A way to check if move occurred.
                      Color moveColor = game.turn;

                      if (pieceMoveData.pieceType == "P" &&
                          ((pieceMoveData.squareName[1] == "7" &&
                                  squareName[1] == "8" &&
                                  pieceMoveData.pieceColor == Color.WHITE) ||
                              (pieceMoveData.squareName[1] == "2" &&
                                  squareName[1] == "1" &&
                                  pieceMoveData.pieceColor == Color.BLACK))) {
                        var val = await _promotionDialog(context);

                        if (val != null) {
                          widget.controller.makeMoveWithPromotion(
                            from: pieceMoveData.squareName,
                            to: squareName,
                            pieceToPromoteTo: val,
                          );
                        } else {
                          return;
                        }
                      } else {
                        widget.controller.makeMove(
                          from: pieceMoveData.squareName,
                          to: squareName,
                        );
                      }
                      if (game.turn != moveColor) {
                        widget.onMove?.call();
                      }
                    });

                    return GestureDetector(
                        onTap: () {
                          //print("tapped: $squareName");
                        },
                        onSecondaryTap: () {
                          widget.onMark?.call(squareName);
                        },
                        onLongPress: () {
                          widget.onMark?.call(squareName);
                        },
                        onSecondaryLongPressMoveUpdate: (details) {
                          //print("pan: ${details.offsetFromOrigin}");
                        },
                        child: dragTarget);
                  },
                  itemCount: 64,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                ),
              ),
              if (widget.arrows.isNotEmpty)
                IgnorePointer(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: CustomPaint(
                      child: Container(),
                      painter:
                          _ArrowPainter(widget.arrows, widget.boardOrientation),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Returns the board image
  Widget _getBoardImage(BoardColor color) {
    switch (color) {
      case BoardColor.brownSvg:
        return SvgPicture.asset(
          "images/brown_board.svg",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
      case BoardColor.brown:
        return Image.asset(
          "images/brown_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
      case BoardColor.darkBrown:
        return Image.asset(
          "images/dark_brown_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
      case BoardColor.green:
        return Image.asset(
          "images/green_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
      case BoardColor.orange:
        return Image.asset(
          "images/orange_board.png",
          package: 'flutter_chess_board',
          fit: BoxFit.cover,
        );
    }
  }

  /// Show dialog when pawn reaches last square
  Future<String?> _promotionDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return new AlertDialog(
          title: new Text('Choose promotion'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              InkWell(
                child: WhiteQueen(),
                onTap: () {
                  Navigator.of(context).pop("q");
                },
              ),
              InkWell(
                child: WhiteRook(),
                onTap: () {
                  Navigator.of(context).pop("r");
                },
              ),
              InkWell(
                child: WhiteBishop(),
                onTap: () {
                  Navigator.of(context).pop("b");
                },
              ),
              InkWell(
                child: WhiteKnight(),
                onTap: () {
                  Navigator.of(context).pop("n");
                },
              ),
            ],
          ),
        );
      },
    ).then((value) {
      return value;
    });
  }
}

class BoardPiece extends StatelessWidget {
  final String squareName;
  final Chess game;

  const BoardPiece({
    Key? key,
    required this.squareName,
    required this.game,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    late Widget imageToDisplay;
    var square = game.get(squareName);

    if (game.get(squareName) == null) {
      return Container();
    }

    String piece = (square?.color == Color.WHITE ? 'W' : 'B') +
        (square?.type.toUpperCase() ?? 'P');

    switch (piece) {
      case "WP":
        imageToDisplay = WhitePawn();
        break;
      case "WR":
        imageToDisplay = WhiteRook();
        break;
      case "WN":
        imageToDisplay = WhiteKnight();
        break;
      case "WB":
        imageToDisplay = WhiteBishop();
        break;
      case "WQ":
        imageToDisplay = WhiteQueen();
        break;
      case "WK":
        imageToDisplay = WhiteKing();
        break;
      case "BP":
        imageToDisplay = BlackPawn();
        break;
      case "BR":
        imageToDisplay = BlackRook();
        break;
      case "BN":
        imageToDisplay = BlackKnight();
        break;
      case "BB":
        imageToDisplay = BlackBishop();
        break;
      case "BQ":
        imageToDisplay = BlackQueen();
        break;
      case "BK":
        imageToDisplay = BlackKing();
        break;
      default:
        imageToDisplay = WhitePawn();
    }

    return imageToDisplay;
  }
}

class PieceMoveData {
  final String squareName;
  final String pieceType;
  final Color pieceColor;

  PieceMoveData({
    required this.squareName,
    required this.pieceType,
    required this.pieceColor,
  });
}

class _ArrowPainter extends CustomPainter {
  List<BoardArrow> arrows;
  PlayerColor boardOrientation;

  _ArrowPainter(this.arrows, this.boardOrientation);

  @override
  void paint(Canvas canvas, Size size) {
    var blockSize = size.width / 8;
    var halfBlockSize = size.width / 16;

    for (var arrow in arrows) {
      var startFile = files.indexOf(arrow.from[0]);
      var startRank = int.parse(arrow.from[1]) - 1;
      var endFile = files.indexOf(arrow.to[0]);
      var endRank = int.parse(arrow.to[1]) - 1;

      int effectiveRowStart = 0;
      int effectiveColumnStart = 0;
      int effectiveRowEnd = 0;
      int effectiveColumnEnd = 0;

      if (boardOrientation == PlayerColor.black) {
        effectiveColumnStart = 7 - startFile;
        effectiveColumnEnd = 7 - endFile;
        effectiveRowStart = startRank;
        effectiveRowEnd = endRank;
      } else {
        effectiveColumnStart = startFile;
        effectiveColumnEnd = endFile;
        effectiveRowStart = 7 - startRank;
        effectiveRowEnd = 7 - endRank;
      }

      var startOffset = Offset(
          ((effectiveColumnStart + 1) * blockSize) - halfBlockSize,
          ((effectiveRowStart + 1) * blockSize) - halfBlockSize);
      var endOffset = Offset(
          ((effectiveColumnEnd + 1) * blockSize) - halfBlockSize,
          ((effectiveRowEnd + 1) * blockSize) - halfBlockSize);

      var dist = endOffset - startOffset;
      var len = dist.distance;
      var dir = dist / len;
      var normal = Offset(-dir.dy, dir.dx);

      var paint = Paint()
        ..strokeWidth = halfBlockSize * arrow.width
        ..color = arrow.color;

      canvas.drawLine(startOffset + (dir * halfBlockSize * 0.5),
          endOffset - (dir * halfBlockSize), paint);

      var newPoint1 = endOffset -
          (dir * halfBlockSize) -
          (normal * halfBlockSize * arrow.width);
      var newPoint2 = endOffset -
          (dir * halfBlockSize) +
          (normal * halfBlockSize * arrow.width);

      var path = Path();

      path.moveTo(endOffset.dx, endOffset.dy);
      path.lineTo(newPoint1.dx, newPoint1.dy);
      path.lineTo(newPoint2.dx, newPoint2.dy);
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return arrows != oldDelegate.arrows;
  }
}
