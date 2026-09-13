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
    final title = _statusTitle(viewerId, isTurn, isCheck);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.grid_on_rounded, color: AppTheme.coral),
            const SizedBox(width: 8),
            const Text('Chess', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            if (widget.state['fullmoveNumber'] != null) Text('Move ${widget.state['fullmoveNumber']}'),
          ]),
          const SizedBox(height: 7),
          Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(color: isCheck ? AppTheme.coral : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
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
                  final dark = (row + column).isOdd;
                  final isSelected = selected == originalIndex;
                  final inCheck = isCheck && value == checkedColor;
                  return InkWell(
                    onTap: isTurn ? () => _tapSquare(originalIndex, value, board, viewerIsWhite) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(color: inCheck ? const Color(0xFFE77A62) : isSelected ? const Color(0xFFE5B85E) : dark ? const Color(0xFF9A6848) : const Color(0xFFF0D6A4)),
                      child: Stack(children: [
                        if (visualColumn == 0) Positioned(left: 3, top: 2, child: Text('${8 - row}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: dark ? Colors.white70 : Colors.black45))),
                        if (visualRow == 7) Positioned(right: 3, bottom: 1, child: Text(String.fromCharCode(97 + column), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: dark ? Colors.white70 : Colors.black45))),
                        Center(child: Text(_piece(value), style: TextStyle(fontSize: 29, color: _pieceColor(value), shadows: const [Shadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 2))]))),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _LegendDot(color: const Color(0xFFF0D6A4), label: perspectiveBlack ? 'Black at bottom' : 'White at bottom'),
            const Spacer(),
            if (selected != null) TextButton(onPressed: () => setState(() => selected = null), child: const Text('Clear selection')),
          ]),
        ]),
      ),
    );
  }

  String _statusTitle(String? viewerId, bool isTurn, bool isCheck) {
    if (widget.match.status == 'finished') {
      if (widget.match.draw) return 'Draw · ${widget.state['drawReason'] ?? 'position repeated'}';
      final winner = widget.match.winnerIds.isEmpty ? null : widget.match.winnerIds.first;
      return winner == viewerId ? 'Checkmate · you win' : 'Checkmate · match finished';
    }
    if (isCheck) return isTurn ? 'Check — find a safe move.' : 'Check — the king must respond.';
    return isTurn ? 'Your turn · select a piece, then its destination.' : 'Waiting for the opponent…';
  }

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
    setState(() => selected = null);
    final fromRow = from ~/ 8;
    final fromColumn = from % 8;
    final toRow = index ~/ 8;
    final toColumn = index % 8;
    final moving = board[fromRow][fromColumn]?.toString();
    if ((moving == 'P' && toRow == 0) || (moving == 'p' && toRow == 7)) {
      _promoteAndSend(fromRow, fromColumn, toRow, toColumn);
      return;
    }
    widget.onAction({'type': 'move', 'fromRow': fromRow, 'fromCol': fromColumn, 'toRow': toRow, 'toCol': toColumn});
  }

  Future<void> _promoteAndSend(int fromRow, int fromColumn, int toRow, int toColumn) async {
    final promotion = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Promote pawn', style: TextStyle(fontWeight: FontWeight.w900))),
          for (final option in const [('q', 'Queen', '♕'), ('r', 'Rook', '♖'), ('b', 'Bishop', '♗'), ('n', 'Knight', '♘')])
            ListTile(leading: Text(option.$3, style: const TextStyle(fontSize: 26)), title: Text(option.$2), onTap: () => Navigator.of(context).pop(option.$1)),
        ]),
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).dividerColor))), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))]);
}
