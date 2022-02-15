/*
    Chess exercises organizer : oad your chess exercises and train yourself against the device.
    Copyright (C) 2022  Laurent Bernabe <laurent.bernabe@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
import 'package:flutter/material.dart';
import 'package:flutter_stateless_chessboard/flutter_stateless_chessboard.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import "package:chess/chess.dart" as chesslib;
import 'package:chess_exercises_organizer/components/richboard.dart';
import 'package:stockfish/stockfish.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';

class GameScreen extends StatefulWidget {
  final int cpuThinkingTimeMs;
  final String startFen;
  const GameScreen({
    Key? key,
    this.cpuThinkingTimeMs = 1000,
    this.startFen = chesslib.Chess.DEFAULT_POSITION,
  }) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  var _chess;
  var _blackAtBottom = false;
  var _lastMove = <String>[];
  var _whitePlayerType = PlayerType.computer;
  var _blackPlayerType = PlayerType.computer;
  var _stockfish;
  var _engineThinking = false;

  @override
  void initState() {
    super.initState();
    _chess = new chesslib.Chess.fromFEN(widget.startFen);
    _initStockfish();
  }

  Future<void> _initStockfish() async {
    _stockfish = new Stockfish();
    _stockfish.stdout.listen(_processStockfishLine);
    await waitUntilStockfishReady();
    _stockfish.stdin = 'isready';
    _makeComputerMove();
  }

  Future<void> waitUntilStockfishReady() async {
    while (_stockfish.state.value != StockfishState.ready) {
      await Future.delayed(Duration(milliseconds: 600));
    }
  }

  _disposeStockfish() {
    _stockfish.dispose();
      _stockfish = null;
  }

  void _makeComputerMove() {
    final whiteTurn = _chess.turn == chesslib.Color.WHITE;
    final humanTurn = (whiteTurn && (_whitePlayerType == PlayerType.human)) ||
        (!whiteTurn && (_blackPlayerType == PlayerType.human));
    if (humanTurn) return;

    if (_chess.game_over) {
        return;
      }

    setState(() {
      _engineThinking = true;
    });

    _stockfish.stdin = 'position fen ${_chess.fen}';
    _stockfish.stdin = 'go movetime ${widget.cpuThinkingTimeMs}';
  }

  void _processStockfishLine(String line) {
    print(line);
    if (line.startsWith('bestmove')) {
      final moveUci = line.split(' ')[1];
      final from = moveUci.substring(0, 2);
      final to = moveUci.substring(2, 4);
      final promotion = moveUci.length >= 5 ? moveUci.substring(4, 5) : null;
      _chess.move(<String, String?>{
        'from': from,
        'to': to,
        'promotion': promotion?.toLowerCase(),
      });
      setState(() {
        _engineThinking = false;
        _lastMove.clear();
        _lastMove.addAll([from, to]);
      });
      if (_chess.game_over) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: _getGameEndedType(),),);
        return;
      }
      else {
        _makeComputerMove();
      }
    }
  }

  void _restartGame() {
    setState(() {
      _chess = new chesslib.Chess.fromFEN(widget.startFen);
      _lastMove.clear();
    });
    _makeComputerMove();
  }

  void _purposeRestartGame(BuildContext context) {
    void closeDialog() {
      Navigator.of(context).pop();
    }

    void doStartNewGame() {
      closeDialog();
      _restartGame();
    }

    final isStartPosition = _chess.fen == chesslib.Chess.DEFAULT_POSITION;
    if (isStartPosition) return;

    showDialog(
      context: context,
      builder: (BuildContext innerCtx) {
        return AlertDialog(
          title: I18nText('game.restart_game_title'),
          content: I18nText('game.restart_game_msg'),
          actions: [
            DialogActionButton(
              onPressed: doStartNewGame,
              textContent: I18nText(
                'buttons.ok',
              ),
              backgroundColor: Colors.tealAccent,
              textColor: Colors.white,
            ),
            DialogActionButton(
              onPressed: closeDialog,
              textContent: I18nText(
                'buttons.cancel',
              ),
              textColor: Colors.white,
              backgroundColor: Colors.redAccent,
            )
          ],
        );
      },
    );
  }

  Future<PieceType?> _handlePromotion(BuildContext context) async {
    final promotion = await _showPromotionDialog(context);
    _makeComputerMove();
    return promotion;
  }

  Future<PieceType?> _showPromotionDialog(BuildContext context) {
    final pieceSize = _getMinScreenSize(context) *
        (_isInLandscapeMode(context) ? 0.75 : 1.0) *
        0.15;
    final whiteTurn = _chess.fen.split(' ')[1] == 'w';
    return showDialog<PieceType>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: I18nText('game.choose_promotion_title'),
            alignment: Alignment.center,
            content: FittedBox(
              child: Row(
                children: [
                  InkWell(
                    child: whiteTurn
                        ? WhiteQueen(size: pieceSize)
                        : BlackQueen(size: pieceSize),
                    onTap: () => Navigator.of(context).pop(PieceType.QUEEN),
                  ),
                  InkWell(
                    child: whiteTurn
                        ? WhiteRook(size: pieceSize)
                        : BlackRook(size: pieceSize),
                    onTap: () => Navigator.of(context).pop(PieceType.ROOK),
                  ),
                  InkWell(
                    child: whiteTurn
                        ? WhiteBishop(size: pieceSize)
                        : BlackBishop(size: pieceSize),
                    onTap: () => Navigator.of(context).pop(PieceType.BISHOP),
                  ),
                  InkWell(
                    child: whiteTurn
                        ? WhiteKnight(size: pieceSize)
                        : BlackKnight(size: pieceSize),
                    onTap: () => Navigator.of(context).pop(PieceType.KNIGHT),
                  ),
                ],
              ),
            ),
          );
        });
  }

  Widget _getGameEndedType() {
    var result = null;
    if (_chess.in_checkmate) {
      result = (_chess.turn == chesslib.Color.WHITE) ? I18nText('game_termination.black_checkmate_white') : I18nText('game_termination.white_checkmate_black');
    }
    else if (_chess.in_stalemate) {
      result = I18nText('game_termination.stalemate');
    }
    else if (_chess.in_threefold_repetition) {
      result = I18nText('game_termination.repetitions');
    }
    else if (_chess.insufficient_material) {
      result = I18nText('game_termination.insufficient_material');
    }
    else if (_chess.in_draw) {
      result = I18nText('game_termination.fifty_moves');
    }
    return result;
  }

  void _tryMakingMove({required ShortMove move}) {
    final success = _chess.move(<String, String?>{
      'from': move.from,
      'to': move.to,
      'promotion': move.promotion.match(
        (piece) => piece.name,
        () => null,
      ),
    });
    if (success) {
      setState(() {
        _lastMove.clear();
        _lastMove.addAll([move.from, move.to]);
      });
      if (_chess.game_over) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: _getGameEndedType(),),);
      }
      _makeComputerMove();
    }
  }

  double _getMinScreenSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return screenWidth < screenHeight ? screenWidth : screenHeight;
  }

  bool _isInLandscapeMode(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  void _toggleBoardOrientation() {
    setState(() {
      _blackAtBottom = !_blackAtBottom;
    });
  }

  @override
  void dispose() {
    _disposeStockfish();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minScreenSize = _getMinScreenSize(context);
    final isInLandscapeMode = _isInLandscapeMode(context);

    const isDebugging = true;

    final tempZone = isDebugging
        ? <Widget>[
            ElevatedButton(
              onPressed: _disposeStockfish,
              child: Row(
                children: [
                  Icon(Icons.warning_rounded),
                  Text(
                    'Dispose stockfish before reload !',
                  )
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _initStockfish,
              child: Row(children: [
                Icon(Icons.warning_rounded),
                Text('Restart stockfish after reload !'),
              ]),
            )
          ]
        : <Widget>[];

    final content = <Widget>[
      RichChessboard(
        engineThinking: _engineThinking,
        fen: _chess.fen,
        size: minScreenSize * (isInLandscapeMode ? 0.75 : 1.0),
        onMove: _tryMakingMove,
        orientation: _blackAtBottom ? BoardColor.BLACK : BoardColor.WHITE,
        whitePlayerType: _whitePlayerType,
        blackPlayerType: _blackPlayerType,
        lastMoveToHighlight: _lastMove,
        onPromote: () => _handlePromotion(context),
      ),
      Column(
        children: [
          ElevatedButton(
            onPressed: () {
              GoRouter.of(context).go('/');
            },
            child: I18nText('game.go_back_home'),
          ),
          ...tempZone,
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: I18nText('game.title'),
        actions: [
          IconButton(
            onPressed: () => _purposeRestartGame(context),
            icon: Icon(
              Icons.restart_alt_outlined,
            ),
          ),
          IconButton(
            icon: Icon(Icons.swap_vert),
            onPressed: _toggleBoardOrientation,
          ),
        ],
      ),
      body: Center(
        child: isInLandscapeMode
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: content,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: content,
              ),
      ),
    );
  }
}

class DialogActionButton extends StatelessWidget {
  final void Function() onPressed;
  final Widget textContent;
  final Color backgroundColor;
  final Color textColor;
  const DialogActionButton({Key? key, required this.onPressed, required this.textContent, required this.backgroundColor, required this.textColor,}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: ElevatedButton(
              onPressed: onPressed,
              child: textContent,
              style: ElevatedButton.styleFrom(
                primary: backgroundColor,
                textStyle: TextStyle(color: textColor,),
                elevation: 5,
              ),
            ),
    );
  }
}