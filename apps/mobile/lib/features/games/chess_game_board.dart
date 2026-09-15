import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class ChessGameBoard extends StatefulWidget {
  const ChessGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<ChessGameBoard> createState() => _ChessGameBoardState();
}

class _ChessGameBoardState extends State<ChessGameBoard> {
  int? selected;

  @override
  void didUpdateWidget(covariant ChessGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final board = (widget.state['board'] as List? ?? const []).map<List<dynamic>>((row) => (row as List).toList()).toList();
    final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    final viewerId = viewer.isEmpty ? null : viewer.first['id']?.toString();
    final isTurn = widget.match.status == 'active' && viewerId != null && widget.state['turnPlayerId'] == viewerId;
    final perspectiveBlack = widget.match.viewerSeat == 1;
    final viewerIsWhite = widget.match.viewerSeat == 0;
    final checkedColor = widget.state['turnIndex'] == 0 ? 'K' : 'k';
    final isCheck = widget.state['inCheck'] == true;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lastMove = _lastMove();
    final viewerCaptured = _captured(board, !viewerIsWhite);
    final oppCaptured = _captured(board, viewerIsWhite);
    final material = _materialOf(viewerCaptured) - _materialOf(oppCaptured);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppTheme.oceanGradient, borderRadius: BorderRadius.circular(13), boxShadow: AppTheme.glow(AppTheme.violet, strength: .35)), child: const Text('♞', style: TextStyle(fontSize: 21, color: Colors.white))),
          const SizedBox(width: 10),
          Text('Chess', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          if (widget.state['fullmoveNumber'] != null) Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppTheme.violet.withOpacity(.3))), child: Text('Move ${widget.state['fullmoveNumber']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
          const SizedBox(width: 7),
          _TurnPill(whiteToMove: widget.state['turnIndex'] != 1),
        ]),
        const SizedBox(height: 8),
        _StatusDot(text: _statusTitle(viewerId, isTurn, isCheck), check: isCheck, finished: widget.match.status == 'finished'),
        const SizedBox(height: 10),
        _CapturedRow(name: _playerName(perspectiveBlack ? 0 : 1), glyphs: oppCaptured, advantage: material < 0 ? -material : 0),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: dark ? [const Color(0xFF4A2E1E), const Color(0xFF2E1B12)] : [const Color(0xFF8A5A3C), const Color(0xFF6B4226)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(.3), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6))],
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemCount: 64,
                itemBuilder: (_, visualIndex) {
                  final visualRow = visualIndex ~/ 8;
                  final visualColumn = visualIndex % 8;
                  final row = perspectiveBlack ? 7 - visualRow : visualRow;
                  final column = perspectiveBlack ? 7 - visualColumn : visualColumn;
                  final value = board.length > row && board[row].length > column ? board[row][column]?.toString() : null;
                  final originalIndex = row * 8 + column;
                  final darkSquare = (row + column).isOdd;
                  final isSelected = selected == originalIndex;
                  final inCheck = isCheck && value == checkedColor;
                  final isLastMove = lastMove != null && (originalIndex == lastMove.$1 || originalIndex == lastMove.$2);
                  return InkWell(
                    onTap: isTurn ? () => _tapSquare(originalIndex, value, board, viewerIsWhite) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: inCheck ? [const Color(0xFFE77A62), const Color(0xFFC4523C)] : isSelected ? [const Color(0xFFEFD28A), const Color(0xFFE0B45C)] : isLastMove ? (darkSquare ? [const Color(0xFFB08A4A), const Color(0xFF96703A)] : [const Color(0xFFF4E2B0), const Color(0xFFE9CE95)]) : darkSquare ? [const Color(0xFF9A6848), const Color(0xFF87573C)] : [const Color(0xFFF0D6A4), const Color(0xFFE3C28C)]),
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: [if (isSelected) const BoxShadow(color: Colors.white54, blurRadius: 10) else if (inCheck) const BoxShadow(color: Color(0xFFE77A62), blurRadius: 12)],
                      ),
                      child: Stack(children: [
                        if (visualColumn == 0) Positioned(left: 3, top: 2, child: Text('${8 - row}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: darkSquare ? Colors.white70 : Colors.black45))),
                        if (visualRow == 7) Positioned(right: 3, bottom: 1, child: Text(String.fromCharCode(97 + column), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: darkSquare ? Colors.white70 : Colors.black45))),
                        Center(child: AnimatedScale(scale: isSelected ? 1.18 : 1, duration: const Duration(milliseconds: 150), child: Text(_piece(value), style: TextStyle(fontSize: 30, color: _pieceColor(value), shadows: const [Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 2))])))),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        _CapturedRow(name: 'You', glyphs: viewerCaptured, advantage: material > 0 ? material : 0),
        const SizedBox(height: 9),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.5), borderRadius: BorderRadius.circular(99)), child: Text(perspectiveBlack ? '● Black at bottom' : '○ White at bottom', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const Spacer(),
          if (selected != null) TextButton(onPressed: () => setState(() => selected = null), child: const Text('Clear selection')),
        ]),
      ],
    );
  }

  (int, int)? _lastMove() {
    final raw = widget.state['lastMove'];
    if (raw is! Map) return null;
    final fr = (raw['fr'] as num?)?.toInt();
    final fc = (raw['fc'] as num?)?.toInt();
    final tr = (raw['tr'] as num?)?.toInt();
    final tc = (raw['tc'] as num?)?.toInt();
    if (fr == null || fc == null || tr == null || tc == null) return null;
    if (fr < 0 || fr > 7 || fc < 0 || fc > 7 || tr < 0 || tr > 7 || tc < 0 || tc > 7) return null;
    return (fr * 8 + fc, tr * 8 + tc);
  }

  List<String> _captured(List<List<dynamic>> board, bool whitePieces) {
    final need = {'p': 8, 'n': 2, 'b': 2, 'r': 2, 'q': 1};
    for (final row in board) {
      for (final cell in row) {
        final value = cell?.toString();
        if (value == null) continue;
        final isWhite = value == value.toUpperCase();
        if (isWhite != whitePieces) continue;
        final lower = value.toLowerCase();
        if (need.containsKey(lower)) need[lower] = need[lower]! - 1;
      }
    }
    final out = <String>[];
    for (final key in ['q', 'r', 'b', 'n', 'p']) {
      for (var i = 0; i < (need[key] ?? 0); i += 1) out.add(whitePieces ? key.toUpperCase() : key);
    }
    return out;
  }

  int _materialOf(List<String> glyphs) {
    var total = 0;
    for (final glyph in glyphs) total += switch (glyph.toLowerCase()) { 'p' => 1, 'n' => 3, 'b' => 3, 'r' => 5, 'q' => 9, _ => 0 };
    return total;
  }

  String _playerName(int seat) {
    final player = widget.match.players.where((candidate) => candidate['seat'] == seat).toList();
    return player.isEmpty ? 'Opponent' : player.first['displayName']?.toString() ?? 'Opponent';
  }

  String _statusTitle(String? viewerId, bool isTurn, bool isCheck) {
    if (widget.match.status == 'finished') {
      if (widget.match.draw) return 'Draw · ${_drawLabel()}';
      final winner = widget.match.winnerIds.isEmpty ? null : widget.match.winnerIds.first;
      return winner == viewerId ? 'Checkmate · you win' : 'Checkmate · match finished';
    }
    if (isCheck) return isTurn ? 'Check — find a safe move.' : 'Check — the king must respond.';
    return isTurn ? 'Your turn · select a piece, then its destination.' : 'Waiting for the opponent…';
  }

  String _drawLabel() => switch (widget.state['drawReason']?.toString()) {
        'stalemate' => 'stalemate',
        'fifty_move' => 'fifty-move rule',
        'threefold_repetition' => 'threefold repetition',
        'insufficient_material' => 'insufficient material',
        _ => 'position repeated',
      };

  void _tapSquare(int index, String? value, List<List<dynamic>> board, bool viewerIsWhite) {
    final own = value != null && (viewerIsWhite ? value == value.toUpperCase() : value == value.toLowerCase());
    if (selected == null) {
      if (own) setState(() => selected = index);
      return;
    }
    if (own) {
      setState(() => selected = index);
      return;
    }
    final from = selected!;
    // Keep the source square highlighted until a newer revision confirms the move.
    final fromRow = from ~/ 8;
    final fromColumn = from % 8;
    final toRow = index ~/ 8;
    final toColumn = index % 8;
    final moving = board[fromRow][fromColumn]?.toString();
    if ((moving == 'P' && toRow == 0) || (moving == 'p' && toRow == 7)) {
      _promoteAndSend(fromRow, fromColumn, toRow, toColumn, viewerIsWhite);
      return;
    }
    widget.onAction({'type': 'move', 'fromRow': fromRow, 'fromCol': fromColumn, 'toRow': toRow, 'toCol': toColumn});
  }

  Future<void> _promoteAndSend(int fromRow, int fromColumn, int toRow, int toColumn, bool viewerIsWhite) async {
    const options = [('q', 'Queen', '♛'), ('r', 'Rook', '♜'), ('b', 'Bishop', '♝'), ('n', 'Knight', '♞')];
    final promotion = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Promote pawn to', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final option in options)
                    InkWell(
                      onTap: () => Navigator.of(sheet).pop(option.$1),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 68,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.1), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.violet.withOpacity(.35))),
                        child: Column(children: [Text(option.$3, style: TextStyle(fontSize: 30, color: viewerIsWhite ? const Color(0xFFFFF9E9) : const Color(0xFF231815), shadows: const [Shadow(color: Colors.black45, blurRadius: 3)])), const SizedBox(height: 4), Text(option.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || promotion == null) return;
    widget.onAction({'type': 'move', 'fromRow': fromRow, 'fromCol': fromColumn, 'toRow': toRow, 'toCol': toColumn, 'promotion': promotion});
  }

  Color _pieceColor(String? value) => value == null ? Colors.transparent : value == value.toUpperCase() ? const Color(0xFFFFF9E9) : const Color(0xFF231815);

  String _piece(String? value) => switch (value) {
        'K' => '♔', 'Q' => '♕', 'R' => '♖', 'B' => '♗', 'N' => '♘', 'P' => '♙',
        'k' => '♚', 'q' => '♛', 'r' => '♜', 'b' => '♝', 'n' => '♞', 'p' => '♟', _ => '',
      };
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.text, required this.check, required this.finished});
  final String text;
  final bool check;
  final bool finished;
  @override
  Widget build(BuildContext context) {
    final color = finished ? AppTheme.gold : check ? AppTheme.coral : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 8)])), const SizedBox(width: 9), Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: check && !finished ? AppTheme.coral : Theme.of(context).colorScheme.onSurfaceVariant)))]);
  }
}

class _TurnPill extends StatelessWidget {
  const _TurnPill({required this.whiteToMove});
  final bool whiteToMove;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.5), borderRadius: BorderRadius.circular(99), border: Border.all(color: Theme.of(context).dividerColor)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 11, height: 11, decoration: BoxDecoration(color: whiteToMove ? Colors.white : const Color(0xFF231815), shape: BoxShape.circle, border: Border.all(color: Colors.black26))), const SizedBox(width: 6), Text(whiteToMove ? 'White to move' : 'Black to move', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11))]),
      );
}

class _CapturedRow extends StatelessWidget {
  const _CapturedRow({required this.name, required this.glyphs, required this.advantage});
  final String name;
  final List<String> glyphs;
  final int advantage;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 26,
        child: Row(children: [
          SizedBox(width: 92, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: glyphs.isEmpty ? Text('—', style: TextStyle(color: Theme.of(context).dividerColor)) : Text(glyphs.map((g) => switch (g) { 'Q' => '♕', 'R' => '♖', 'B' => '♗', 'N' => '♘', 'P' => '♙', 'q' => '♛', 'r' => '♜', 'b' => '♝', 'n' => '♞', 'p' => '♟', _ => '' }).join(' '), style: const TextStyle(fontSize: 16))),
          if (advantage > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.15), borderRadius: BorderRadius.circular(99)), child: Text('+$advantage', style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w900, fontSize: 11))),
        ]),
      );
}
