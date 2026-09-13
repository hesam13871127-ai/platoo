import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class FourInARowGameBoard extends StatelessWidget {
  const FourInARowGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  Widget build(BuildContext context) {
    final board = (state['board'] as List? ?? const []).map((row) => (row as List).map((cell) => (cell as num).toInt()).toList()).toList();
    final ownPlayers = match.players.where((player) => player['seat'] == match.viewerSeat).toList();
    final isTurn = ownPlayers.isNotEmpty && state['turnPlayerId'] == ownPlayers.first['id'] && match.status == 'active';
    final moveCount = (state['moveCount'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.view_week_rounded, color: AppTheme.coral),
            const SizedBox(width: 8),
            const Text('4 in a Row', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            Text('$moveCount / 42', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 10),
          Text(isTurn ? 'Choose a column.' : 'Waiting for the other player…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 7 / 6,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                for (var row = 0; row < 6; row += 1)
                  Expanded(child: Row(children: [
                    for (var column = 0; column < 7; column += 1)
                      Expanded(child: InkWell(
                        onTap: isTurn && board.isNotEmpty && board[0][column] == 0 ? () => onAction({'type': 'drop', 'column': column}) : null,
                        borderRadius: BorderRadius.circular(99),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(color: _pieceColor(board, row, column), shape: BoxShape.circle),
                          ),
                        ),
                      )),
                  ])),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Color _pieceColor(List<List<int>> board, int row, int column) {
    final value = board.length > row && board[row].length > column ? board[row][column] : 0;
    return switch (value) {
      1 => AppTheme.coral,
      2 => AppTheme.gold,
      _ => Colors.white.withOpacity(.9),
    };
  }
}
