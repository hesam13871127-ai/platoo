import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class CheckersGameBoard extends StatefulWidget {
  const CheckersGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<CheckersGameBoard> createState() => _CheckersGameBoardState();
}

class _CheckersGameBoardState extends State<CheckersGameBoard> {
  int? selected;

  @override
  void didUpdateWidget(covariant CheckersGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) selected = null;
  }

  List<List<String?>> get _board {
    final raw = widget.state['board'] as List? ?? const [];
    return List.generate(8, (r) {
      final row = r < raw.length && raw[r] is List ? raw[r] as List : const [];
      return List.generate(8, (c) => c < row.length ? row[c]?.toString() : null);
    });
  }

  String get _color => widget.match.viewerSeat == 0 ? 'r' : 'b';

  bool get _isTurn {
    final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    return widget.match.status == 'active' && viewer.isNotEmpty && widget.state['turnPlayerId'] == viewer.first['id'];
  }

  List<int>? get _forcedFrom {
    final forced = widget.state['forcedFrom'];
    if (forced is! Map) return null;
    final r = (forced['r'] as num?)?.toInt();
    final c = (forced['c'] as num?)?.toInt();
    if (r == null || c == null) return null;
    return [r, c];
  }

  bool _inside(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  List<List<int>> _movesFor(List<List<String?>> board, int r, int c, String piece, bool captureOnly) {
    final king = piece == piece.toUpperCase();
    final dirs = king
        ? const [[1, 1], [1, -1], [-1, 1], [-1, -1]]
        : piece == 'r'
            ? const [[-1, 1], [-1, -1]]
            : const [[1, 1], [1, -1]];
    final moves = <List<int>>[];
    for (final d in dirs) {
      final nr = r + d[0];
      final nc = c + d[1];
      final jr = r + d[0] * 2;
      final jc = c + d[1] * 2;
      if (!captureOnly && _inside(nr, nc) && board[nr][nc] == null) moves.add([nr, nc]);
      if (_inside(nr, nc) && _inside(jr, jc) && board[nr][nc] != null && board[nr][nc]!.toLowerCase() != piece.toLowerCase() && board[jr][jc] == null) {
        moves.add([jr, jc]);
      }
    }
    return moves;
  }

  bool _hasAnyCapture(List<List<String?>> board, String color) {
    for (var r = 0; r < 8; r += 1) {
      for (var c = 0; c < 8; c += 1) {
        final piece = board[r][c];
        if (piece != null && piece.toLowerCase() == color && _movesFor(board, r, c, piece, true).any((m) => (m[0] - r).abs() == 2)) {
          return true;
        }
      }
    }
    return false;
  }

  int _count(List<List<String?>> board, String color) {
    var total = 0;
    for (final row in board) {
      for (final piece in row) {
        if (piece != null && piece.toLowerCase() == color) total += 1;
      }
    }
    return total;
  }

  void _tap(int r, int c, List<List<String?>> board, bool captureOnly, List<int>? forced) {
    if (!_isTurn) return;
    final piece = board[r][c];
    if (selected != null) {
      final sr = selected! ~/ 8;
      final sc = selected! % 8;
      final mine = board[sr][sc];
      if (mine != null && _movesFor(board, sr, sc, mine, captureOnly).any((m) => m[0] == r && m[1] == c)) {
        widget.onAction({'type': 'move', 'fromRow': sr, 'fromCol': sc, 'toRow': r, 'toCol': c});
        setState(() => selected = null);
        return;
      }
    }
    if (piece != null && piece.toLowerCase() == _color) {
      if (forced != null && (forced[0] != r || forced[1] != c)) return;
      if (_movesFor(board, r, c, piece, captureOnly).isEmpty) return;
      setState(() => selected = selected == r * 8 + c ? null : r * 8 + c);
    } else {
      setState(() => selected = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final flipped = widget.match.viewerSeat == 1;
    final forced = _forcedFrom;
    final captureOnly = _hasAnyCapture(board, _color);
    final targets = <int>{};
    if (selected != null && _isTurn) {
      final sr = selected! ~/ 8;
      final sc = selected! % 8;
      final piece = board[sr][sc];
      if (piece != null) {
        for (final m in _movesFor(board, sr, sc, piece, captureOnly)) {
          targets.add(m[0] * 8 + m[1]);
        }
      }
    }
    final mine = _count(board, _color);
    final theirs = _count(board, _color == 'r' ? 'b' : 'r');
    final status = finished
        ? 'Match complete'
        : !_isTurn
            ? 'Waiting for the other player…'
            : forced != null
                ? 'Capture again — keep jumping!'
                : captureOnly
                    ? 'A capture is available — you must take it.'
                    : selected == null
                        ? 'Select one of your pieces.'
                        : 'Choose a highlighted square.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.grid_4x4_rounded, color: AppTheme.coral),
            const SizedBox(width: 8),
            const VibeText('Checkers', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            _CountPill(count: mine, mine: true),
            const SizedBox(width: 6),
            _CountPill(count: theirs, mine: false),
          ]),
          const SizedBox(height: 7),
          Align(alignment: Alignment.centerLeft, child: VibeText(status, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
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
                  final vr = visualIndex ~/ 8;
                  final vc = visualIndex % 8;
                  final r = flipped ? 7 - vr : vr;
                  final c = flipped ? 7 - vc : vc;
                  final piece = board[r][c];
                  final dark = (r + c).isOdd;
                  final isSelected = selected == r * 8 + c;
                  final isTarget = targets.contains(r * 8 + c);
                  final tappable = _isTurn && !finished && (isTarget || (piece != null && piece.toLowerCase() == _color));
                  return InkWell(
                    onTap: tappable || (piece != null && _isTurn) ? () => _tap(r, c, board, captureOnly, forced) : null,
                    child: Container(
                      color: isSelected
                          ? AppTheme.coral.withOpacity(.55)
                          : isTarget
                              ? AppTheme.mint.withOpacity(.5)
                              : dark
                                  ? const Color(0xFFB98D67)
                                  : const Color(0xFFF1D2A9),
                      child: Center(
                        child: piece == null
                            ? (isTarget ? Container(width: 14, height: 14, decoration: const BoxDecoration(color: AppTheme.mint, shape: BoxShape.circle)) : null)
                            : _Piece(color: piece.toLowerCase(), king: piece == piece.toUpperCase()),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Piece extends StatelessWidget {
  const _Piece({required this.color, required this.king});
  final String color;
  final bool king;

  @override
  Widget build(BuildContext context) {
    final base = color == 'r' ? AppTheme.coral : const Color(0xFF2B2320);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: base, shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.65), width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))]),
      child: king ? const Icon(Icons.workspace_premium_rounded, color: AppTheme.gold, size: 17) : null,
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.mine});
  final int count;
  final bool mine;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: (mine ? AppTheme.coral : AppTheme.gold).withOpacity(.14), borderRadius: BorderRadius.circular(99)),
        child: VibeText(mine ? 'You · $count' : 'Foe · $count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: mine ? AppTheme.coral : AppTheme.gold)),
      );
}
