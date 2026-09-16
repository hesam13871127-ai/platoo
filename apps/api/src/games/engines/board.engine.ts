import { Action, asInt, GameEngine, GameId, GameOutcome, GamePlayer, GameState, IllegalMoveError, clone, nextTurn, randomInt, rotateTurn } from '../game.types';

function turnCheck(state: GameState, actorId: string): void {
  if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.');
  if (state.winnerId || state.finished) throw new IllegalMoveError('This game has finished.');
}

export class FourInARowEngine implements GameEngine {
  readonly id: GameId = 'four_in_a_row';
  create(players: GamePlayer[]): GameState {
    if (players.length !== 2) throw new IllegalMoveError('4 in a Row requires exactly two players.');
    return { board: Array.from({ length: 6 }, () => Array(7).fill(0)), turnIndex: 0, turnPlayerId: players[0].id, moveCount: 0, winnerId: null, finished: false };
  }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void {
    turnCheck(state, actorId); if (action.type !== 'drop') throw new IllegalMoveError('Use the drop action.');
    const column = asInt(action.column, 'column', 0, 6); const board = state.board as number[][];
    if (board[0][column] !== 0) throw new IllegalMoveError('That column is full.');
    if (!players.some((p) => p.id === actorId)) throw new IllegalMoveError('You are not in this game.');
  }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState {
    this.validate(state, actorId, action, players); const next = clone(state); const board = next.board as number[][]; const column = action.column as number;
    let row = 5; while (row >= 0 && board[row][column] !== 0) row -= 1; board[row][column] = players.findIndex((p) => p.id === actorId) + 1; next.moveCount = Number(next.moveCount) + 1;
    if (this.hasLine(board, row, column, board[row][column])) { next.winnerId = actorId; next.finished = true; }
    else if (Number(next.moveCount) === 42) { next.draw = true; next.finished = true; } else rotateTurn(next, players);
    return next;
  }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; }
  botAction(state: GameState, botId: string, players: GamePlayer[]): Action {
    const board = (state.board as number[][]).map((row) => [...row]);
    const side = players.findIndex((player) => player.id === botId);
    const mine = side + 1;
    const theirs = side === 0 ? 2 : 1;
    const legal = Array.from({ length: 7 }, (_, column) => column).filter((column) => board[0][column] === 0);
    const rowFor = (column: number): number => { let row = 5; while (row >= 0 && board[row][column] !== 0) row -= 1; return row; };
    for (const column of legal) {
      const row = rowFor(column);
      board[row][column] = mine;
      const wins = this.hasLine(board, row, column, mine);
      board[row][column] = 0;
      if (wins) return { type: 'drop', column };
    }
    for (const column of legal) {
      const row = rowFor(column);
      board[row][column] = theirs;
      const blocks = this.hasLine(board, row, column, theirs);
      board[row][column] = 0;
      if (blocks) return { type: 'drop', column };
    }
    const preferred = [3, 2, 4, 1, 5, 0, 6].filter((column) => legal.includes(column));
    const column = Math.random() < 0.8 ? preferred[0] : preferred[randomInt(preferred.length)];
    return { type: 'drop', column: column ?? legal[0] ?? 0 };
  }
  private hasLine(board: number[][], row: number, col: number, value: number): boolean { return [[1, 0], [0, 1], [1, 1], [1, -1]].some(([dr, dc]) => 1 + this.count(board, row, col, dr, dc, value) + this.count(board, row, col, -dr, -dc, value) >= 4); }
  private count(board: number[][], row: number, col: number, dr: number, dc: number, value: number): number { let count = 0; let r = row + dr; let c = col + dc; while (r >= 0 && r < 6 && c >= 0 && c < 7 && board[r][c] === value) { count += 1; r += dr; c += dc; } return count; }
}

export class MancalaEngine implements GameEngine {
  readonly id: GameId = 'mancala';
  create(players: GamePlayer[]): GameState { if (players.length !== 2) throw new IllegalMoveError('Mancala requires exactly two players.'); return { pits: [Array(6).fill(4), Array(6).fill(4)], stores: [0, 0], turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { turnCheck(state, actorId); if (action.type !== 'sow') throw new IllegalMoveError('Use the sow action.'); const pit = asInt(action.pit, 'pit', 0, 5); const side = players.findIndex((p) => p.id === actorId); if (side < 0) throw new IllegalMoveError('You are not in this game.'); if ((state.pits as number[][])[side][pit] < 1) throw new IllegalMoveError('That pit is empty.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); const pits = next.pits as number[][]; const stores = next.stores as number[]; let stones = pits[side][action.pit as number]; pits[side][action.pit as number] = 0; let currentSide = side; let index = action.pit as number; let lastStore = false;
    while (stones > 0) { index += 1; if (index === 6) { if (currentSide === side) { stores[side] += 1; stones -= 1; lastStore = stones === 0; } index = -1; currentSide = currentSide === 0 ? 1 : 0; } else { pits[currentSide][index] += 1; stones -= 1; lastStore = false; if (stones === 0 && currentSide === side && pits[currentSide][index] === 1 && pits[1 - side][5 - index] > 0) { stores[side] += pits[1 - side][5 - index] + 1; pits[1 - side][5 - index] = 0; pits[side][index] = 0; } } }
    const sideEmpty = pits[side].every((stone) => stone === 0); const otherEmpty = pits[1 - side].every((stone) => stone === 0); if (sideEmpty || otherEmpty) { for (let s = 0; s < 2; s += 1) { stores[s] += pits[s].reduce((a, b) => a + b, 0); pits[s].fill(0); } next.finished = true; next.winnerId = stores[0] === stores[1] ? null : players[stores[0] > stores[1] ? 0 : 1].id; next.draw = stores[0] === stores[1]; } else if (!lastStore) rotateTurn(next, players); return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; }
  botAction(state: GameState, botId: string, players: GamePlayer[]): Action { const side = players.findIndex((p) => p.id === botId); const legal = (state.pits as number[][])[side].map((stone, pit) => stone > 0 ? pit : -1).filter((pit) => pit >= 0); return { type: 'sow', pit: legal[randomInt(legal.length)] ?? 0 }; }
}

export class CheckersEngine implements GameEngine {
  readonly id: GameId = 'checkers';
  create(players: GamePlayer[]): GameState {
    if (players.length !== 2) throw new IllegalMoveError('Checkers requires exactly two players.');
    const board: (string | null)[][] = Array.from({ length: 8 }, () => Array(8).fill(null));
    for (let r = 0; r < 3; r += 1) for (let c = 0; c < 8; c += 1) if ((r + c) % 2 === 1) board[r][c] = 'b';
    for (let r = 5; r < 8; r += 1) for (let c = 0; c < 8; c += 1) if ((r + c) % 2 === 1) board[r][c] = 'r';
    return { board, turnIndex: 0, turnPlayerId: players[0].id, forcedFrom: null, winnerId: null, finished: false, draw: false, halfmoveClock: 0, positionCounts: { [this.positionKey(board)]: 1 } };
  }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { turnCheck(state, actorId); if (action.type !== 'move') throw new IllegalMoveError('Use the move action.'); const from = this.square(action.fromRow, action.fromCol); const to = this.square(action.toRow, action.toCol); const board = state.board as (string | null)[][]; const piece = board[from.r][from.c]; const color = players.findIndex((p) => p.id === actorId) === 0 ? 'r' : 'b'; if (!piece || piece.toLowerCase() !== color) throw new IllegalMoveError('That is not your piece.'); if (state.forcedFrom && (state.forcedFrom as { r: number; c: number }).r !== from.r) throw new IllegalMoveError('You must continue the capture.'); if (state.forcedFrom && (state.forcedFrom as { r: number; c: number }).c !== from.c) throw new IllegalMoveError('You must continue the capture.'); if (board[to.r][to.c]) throw new IllegalMoveError('The destination is occupied.'); const moves = this.movesFor(board, from.r, from.c, piece, this.hasAnyCapture(board, color)); if (!moves.some((m) => m.r === to.r && m.c === to.c)) throw new IllegalMoveError('That move is not legal.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState {
    this.validate(state, actorId, action, players);
    const next = clone(state);
    const board = next.board as (string | null)[][];
    const fr = action.fromRow as number;
    const fc = action.fromCol as number;
    const tr = action.toRow as number;
    const tc = action.toCol as number;
    let piece = board[fr][fc] as string;
    const wasKing = piece === piece.toUpperCase();
    board[fr][fc] = null;
    const isCapture = Math.abs(tr - fr) === 2;
    if (isCapture) board[(fr + tr) / 2][(fc + tc) / 2] = null;
    if (piece === 'r' && tr === 0) piece = 'R';
    if (piece === 'b' && tr === 7) piece = 'B';
    board[tr][tc] = piece;
    const promoted = !wasKing && piece === piece.toUpperCase();
    // In American checkers a man that reaches the king row is crowned and
    // the capture sequence ends immediately; it does not continue as a king.
    const moreCapture = !promoted && isCapture && this.movesFor(board, tr, tc, piece, true).length > 0;
    if (moreCapture) {
      next.forcedFrom = { r: tr, c: tc };
    } else {
      next.forcedFrom = null;
      rotateTurn(next, players);
    }
    const nextColor = players.findIndex((player) => player.id === next.turnPlayerId) === 0 ? 'r' : 'b';
    if (!this.hasPieces(board, nextColor) || !this.hasAnyLegalMove(board, nextColor)) {
      next.finished = true;
      next.winnerId = actorId;
    }
    const halfmoveClock = isCapture || promoted ? 0 : Number(next.halfmoveClock ?? 0) + 1;
    next.halfmoveClock = halfmoveClock;
    const positionCounts = { ...((next.positionCounts as Record<string, number> | undefined) ?? {}) };
    const key = this.positionKey(board, Number(next.turnIndex));
    positionCounts[key] = (positionCounts[key] ?? 0) + 1;
    next.positionCounts = positionCounts;
    if (!next.finished && (halfmoveClock >= 80 || positionCounts[key] >= 3)) {
      next.finished = true;
      next.draw = true;
      next.drawReason = halfmoveClock >= 80 ? 'forty_move_rule' : 'threefold_repetition';
    }
    return next;
  }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; }
  botAction(state: GameState, botId: string, players: GamePlayer[]): Action {
    const board = state.board as (string | null)[][];
    const color = players.findIndex((player) => player.id === botId) === 0 ? 'r' : 'b';
    const forced = state.forcedFrom as { r: number; c: number } | null;
    const mustCapture = this.hasAnyCapture(board, color);
    const moves: Action[] = [];
    for (let r = 0; r < 8; r += 1) for (let c = 0; c < 8; c += 1) {
      if (forced && (forced.r !== r || forced.c !== c)) continue;
      const piece = board[r][c];
      if (piece?.toLowerCase() !== color) continue;
      for (const move of this.movesFor(board, r, c, piece, mustCapture)) moves.push({ type: 'move', fromRow: r, fromCol: c, toRow: move.r, toCol: move.c });
    }
    // Prefer captures and promotions, but retain a little variety rather than
    // making every bot follow the same deterministic line.
    moves.sort((a, b) => {
      const aCapture = Math.abs((a.toRow as number) - (a.fromRow as number)) === 2 ? 1 : 0;
      const bCapture = Math.abs((b.toRow as number) - (b.fromRow as number)) === 2 ? 1 : 0;
      const aPromotion = (a.toRow as number) === (color === 'r' ? 0 : 7) ? 1 : 0;
      const bPromotion = (b.toRow as number) === (color === 'r' ? 0 : 7) ? 1 : 0;
      return (bCapture * 4 + bPromotion * 2) - (aCapture * 4 + aPromotion * 2) || Math.random() - 0.5;
    });
    return moves[0] ?? { type: 'move', fromRow: 0, fromCol: 0, toRow: 0, toCol: 0 };
  }
  private square(r: unknown, c: unknown): { r: number; c: number } { return { r: asInt(r, 'row', 0, 7), c: asInt(c, 'column', 0, 7) }; }
  private movesFor(board: (string | null)[][], r: number, c: number, piece: string, captureOnly: boolean): Array<{ r: number; c: number }> { const directions = piece.toUpperCase() === piece ? [[1, 1], [1, -1], [-1, 1], [-1, -1]] : piece === 'r' ? [[-1, 1], [-1, -1]] : [[1, 1], [1, -1]]; const moves: Array<{ r: number; c: number }> = []; for (const [dr, dc] of directions) { const nr = r + dr; const nc = c + dc; const jr = r + dr * 2; const jc = c + dc * 2; if (!captureOnly && this.inside(nr, nc) && !board[nr][nc]) moves.push({ r: nr, c: nc }); if (this.inside(jr, jc) && board[nr]?.[nc] && board[nr][nc]?.toLowerCase() !== piece.toLowerCase() && !board[jr][jc]) moves.push({ r: jr, c: jc }); } return moves; }
  private hasAnyCapture(board: (string | null)[][], color: string): boolean { for (let r = 0; r < 8; r += 1) for (let c = 0; c < 8; c += 1) { const piece = board[r][c]; if (piece?.toLowerCase() === color && this.movesFor(board, r, c, piece, true).some((m) => Math.abs(m.r - r) === 2)) return true; } return false; }
  private hasAnyLegalMove(board: (string | null)[][], color: string): boolean { const capture = this.hasAnyCapture(board, color); for (let r = 0; r < 8; r += 1) for (let c = 0; c < 8; c += 1) { const piece = board[r][c]; if (piece?.toLowerCase() === color && this.movesFor(board, r, c, piece, capture).length) return true; } return false; }
  private hasPieces(board: (string | null)[][], color: string): boolean { return board.some((row) => row.some((piece) => piece?.toLowerCase() === color)); }
  private positionKey(board: (string | null)[][], turn = 0): string { return `${board.map((row) => row.map((piece) => piece ?? '.').join('')).join('/')}|${turn}`; }
  private inside(r: number, c: number): boolean { return r >= 0 && r < 8 && c >= 0 && c < 8; }
}

interface ChessState extends GameState {
  board: (string | null)[][];
  turnIndex: number;
  turnPlayerId: string;
  castling: { K: boolean; Q: boolean; k: boolean; q: boolean };
  enPassant: { r: number; c: number } | null;
  lastMove: { fr: number; fc: number; tr: number; tc: number } | null;
  winnerId: string | null;
  finished: boolean;
  draw?: boolean;
  inCheck: boolean;
  drawReason?: string;
  halfmoveClock: number;
  fullmoveNumber: number;
  positionCounts: Record<string, number>;
}

interface ChessMove { fr: number; fc: number; tr: number; tc: number; promotion?: 'q' | 'r' | 'b' | 'n'; }

export class ChessEngine implements GameEngine {
  readonly id: GameId = 'chess';

  create(players: GamePlayer[]): ChessState {
    if (players.length !== 2) throw new IllegalMoveError('Chess requires exactly two players.');
    const board: (string | null)[][] = [
      ['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'],
      Array(8).fill('p'),
      ...Array.from({ length: 4 }, () => Array(8).fill(null)),
      Array(8).fill('P'),
      ['R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R'],
    ];
    const state: ChessState = {
      board,
      turnIndex: 0,
      turnPlayerId: players[0].id,
      castling: { K: true, Q: true, k: true, q: true },
      enPassant: null,
      lastMove: null,
      winnerId: null,
      finished: false,
      inCheck: false,
      halfmoveClock: 0,
      fullmoveNumber: 1,
      positionCounts: {},
    };
    state.positionCounts[this.positionKey(state, 'w')] = 1;
    return state;
  }

  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void {
    const chess = state as ChessState;
    turnCheck(chess, actorId);
    if (action.type !== 'move') throw new IllegalMoveError('Use the move action.');
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    const color = side === 0 ? 'w' : 'b';
    const from = this.coord(action.fromRow, action.fromCol);
    const to = this.coord(action.toRow, action.toCol);
    const requestedPromotion = this.promotion(action.promotion);
    if (action.promotion !== undefined && !requestedPromotion) throw new IllegalMoveError('Promotion must be q, r, b, or n.');
    if (!this.findLegalMove(chess, color, from.r, from.c, to.r, to.c, requestedPromotion)) throw new IllegalMoveError('That move is not legal.');
  }

  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): ChessState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as ChessState;
    const side = players.findIndex((player) => player.id === actorId);
    const color = side === 0 ? 'w' : 'b';
    const from = this.coord(action.fromRow, action.fromCol);
    const to = this.coord(action.toRow, action.toCol);
    const promotion = this.promotion(action.promotion) ?? 'q';
    const move = this.findLegalMove(next, color, from.r, from.c, to.r, to.c, promotion);
    if (!move) throw new IllegalMoveError('That move is not legal.');

    const moving = next.board[move.fr][move.fc] as string;
    const captured = next.board[move.tr][move.tc];
    const enPassantCapture = moving.toLowerCase() === 'p' && next.enPassant?.r === move.tr && next.enPassant.c === move.tc && !captured;
    this.applyBoardMove(next, move);
    next.lastMove = { fr: move.fr, fc: move.fc, tr: move.tr, tc: move.tc };
    this.updateCastlingRights(next, moving, move, captured);
    next.enPassant = moving.toLowerCase() === 'p' && Math.abs(move.tr - move.fr) === 2 ? { r: (move.tr + move.fr) / 2, c: move.fc } : null;
    next.halfmoveClock = moving.toLowerCase() === 'p' || captured || enPassantCapture ? 0 : Number(next.halfmoveClock ?? 0) + 1;
    if (color === 'b') next.fullmoveNumber = Number(next.fullmoveNumber ?? 1) + 1;
    rotateTurn(next, players);

    const nextColor = color === 'w' ? 'b' : 'w';
    const key = this.positionKey(next, nextColor);
    next.positionCounts = next.positionCounts ?? {};
    next.positionCounts[key] = Number(next.positionCounts[key] ?? 0) + 1;
    const inCheck = this.inCheck(next.board, nextColor);
    next.inCheck = inCheck;
    const legal = this.legalMoves(next, nextColor);
    if (!legal.length) {
      next.finished = true;
      if (inCheck) {
        next.winnerId = actorId;
        next.drawReason = 'checkmate';
      } else {
        next.draw = true;
        next.drawReason = 'stalemate';
      }
    } else if (Number(next.halfmoveClock) >= 100 || Number(next.positionCounts[key]) >= 3 || this.insufficientMaterial(next.board)) {
      next.finished = true;
      next.draw = true;
      next.drawReason = Number(next.halfmoveClock) >= 100 ? 'fifty_move' : Number(next.positionCounts[key]) >= 3 ? 'threefold_repetition' : 'insufficient_material';
    }
    return next;
  }

  outcome(state: ChessState, players: GamePlayer[]): GameOutcome {
    const winner = typeof state.winnerId === 'string' ? state.winnerId : '';
    return {
      finished: Boolean(state.finished),
      winnerIds: winner ? [winner] : [],
      loserIds: winner ? players.filter((player) => player.id !== winner).map((player) => player.id) : [],
      draw: Boolean(state.draw),
    };
  }

  botAction(state: GameState, botId: string, players: GamePlayer[]): Action {
    const chess = state as ChessState;
    const side = players.findIndex((player) => player.id === botId);
    const color = side === 0 ? 'w' : 'b';
    const enemy = color === 'w' ? 'b' : 'w';
    const moves = this.legalMoves(chess, color);
    let best = moves[randomInt(moves.length)];
    if (!moves.length || !best) throw new IllegalMoveError('The chess match has no legal moves.');
    let bestScore = -Infinity;
    for (const move of moves) {
      const attacker = chess.board[move.fr][move.fc] as string;
      const victim = chess.board[move.tr][move.tc];
      const isEnPassant = attacker.toLowerCase() === 'p' && !victim && chess.enPassant?.r === move.tr && chess.enPassant.c === move.tc;
      let score = Math.random() * 2;
      if (victim) score += 10 * this.pieceValue(victim) - this.pieceValue(attacker);
      if (isEnPassant) score += 10;
      if (move.promotion) score += move.promotion === 'q' ? 90 : 40;
      if (attacker.toLowerCase() === 'k' && Math.abs(move.tc - move.fc) === 2) score += 12;
      if (attacker === 'P' && move.fr === 6) score += 3;
      if (attacker === 'p' && move.fr === 1) score += 3;
      if ((attacker === 'N' || attacker === 'n' || attacker === 'B' || attacker === 'b') && (move.fr === 0 || move.fr === 7)) score += 4;
      score += (3 - Math.abs(3.5 - move.tr) - Math.abs(3.5 - move.tc)) * 0.4;
      const copy = clone(chess) as ChessState;
      this.applyBoardMove(copy, move);
      if (this.inCheck(copy.board, enemy)) {
        score += 12;
        if (this.legalMoves(copy, enemy).length === 0) score += 10000;
      }
      if (this.attacked(copy.board, move.tr, move.tc, enemy)) {
        const hanging = victim ? Math.max(0, this.pieceValue(attacker) - this.pieceValue(victim)) : this.pieceValue(attacker);
        score -= hanging * 0.6;
      }
      if (score > bestScore) { bestScore = score; best = move; }
    }
    return {
      type: 'move',
      fromRow: best.fr,
      fromCol: best.fc,
      toRow: best.tr,
      toCol: best.tc,
      ...(best.promotion ? { promotion: best.promotion } : {}),
    };
  }

  private pieceValue(piece: string): number {
    switch (piece.toLowerCase()) {
      case 'p': return 1;
      case 'n': return 3;
      case 'b': return 3;
      case 'r': return 5;
      case 'q': return 9;
      default: return 0;
    }
  }

  private findLegalMove(state: ChessState, color: 'w' | 'b', fr: number, fc: number, tr: number, tc: number, requestedPromotion?: 'q' | 'r' | 'b' | 'n'): ChessMove | undefined {
    return this.legalMoves(state, color).find((move) => move.fr === fr && move.fc === fc && move.tr === tr && move.tc === tc && (!move.promotion || move.promotion === (requestedPromotion ?? 'q')));
  }

  private legalMoves(state: ChessState, color: 'w' | 'b'): ChessMove[] {
    return this.pseudoMoves(state, color).filter((move) => {
      const copy = clone(state) as ChessState;
      this.applyBoardMove(copy, move);
      return !this.inCheck(copy.board, color);
    });
  }

  private pseudoMoves(state: ChessState, color: 'w' | 'b'): ChessMove[] {
    const moves: ChessMove[] = [];
    for (let r = 0; r < 8; r += 1) {
      for (let c = 0; c < 8; c += 1) {
        const piece = state.board[r][c];
        if (!piece || this.color(piece) !== color) continue;
        const lower = piece.toLowerCase();
        if (lower === 'p') {
          const direction = color === 'w' ? -1 : 1;
          const start = color === 'w' ? 6 : 1;
          const promotionRow = color === 'w' ? 0 : 7;
          if (this.inside(r + direction, c) && !state.board[r + direction][c]) {
            this.addPawnMove(moves, r, c, r + direction, c, promotionRow);
            if (r === start && !state.board[r + 2 * direction][c]) moves.push({ fr: r, fc: c, tr: r + 2 * direction, tc: c });
          }
          for (const dc of [-1, 1]) {
            const tr = r + direction;
            const tc = c + dc;
            if (!this.inside(tr, tc)) continue;
            const target = state.board[tr][tc];
            const isEnPassant = state.enPassant?.r === tr && state.enPassant.c === tc && !target && state.board[r][tc] === (color === 'w' ? 'p' : 'P');
            if ((target && this.color(target) !== color && target.toLowerCase() !== 'k') || isEnPassant) this.addPawnMove(moves, r, c, tr, tc, promotionRow);
          }
        } else if (lower === 'n') {
          for (const [dr, dc] of [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]]) this.addTargetMove(state, moves, r, c, r + dr, c + dc, color);
        } else if (lower === 'k') {
          for (const [dr, dc] of [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]) this.addTargetMove(state, moves, r, c, r + dr, c + dc, color);
          this.addCastlingMoves(state, moves, color, r, c);
        } else {
          const directions = lower === 'b'
            ? [[1, 1], [1, -1], [-1, 1], [-1, -1]]
            : lower === 'r'
              ? [[1, 0], [-1, 0], [0, 1], [0, -1]]
              : [[1, 1], [1, -1], [-1, 1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]];
          for (const [dr, dc] of directions) {
            let tr = r + dr;
            let tc = c + dc;
            while (this.inside(tr, tc)) {
              const continues = this.addTargetMove(state, moves, r, c, tr, tc, color);
              if (!continues || state.board[tr][tc]) break;
              tr += dr;
              tc += dc;
            }
          }
        }
      }
    }
    return moves;
  }

  private addPawnMove(moves: ChessMove[], fr: number, fc: number, tr: number, tc: number, promotionRow: number): void {
    if (tr !== promotionRow) {
      moves.push({ fr, fc, tr, tc });
      return;
    }
    for (const promotion of ['q', 'r', 'b', 'n'] as const) moves.push({ fr, fc, tr, tc, promotion });
  }

  private addTargetMove(state: ChessState, moves: ChessMove[], fr: number, fc: number, tr: number, tc: number, color: 'w' | 'b'): boolean {
    if (!this.inside(tr, tc)) return false;
    const target = state.board[tr][tc];
    if (!target || (this.color(target) !== color && target.toLowerCase() !== 'k')) moves.push({ fr, fc, tr, tc });
    return !target;
  }

  private addCastlingMoves(state: ChessState, moves: ChessMove[], color: 'w' | 'b', row: number, column: number): void {
    if (row !== (color === 'w' ? 7 : 0) || column !== 4 || this.inCheck(state.board, color)) return;
    const enemy = color === 'w' ? 'b' : 'w';
    const rights = color === 'w' ? state.castling : { K: state.castling.k, Q: state.castling.q };
    const king = color === 'w' ? 'K' : 'k';
    const rook = color === 'w' ? 'R' : 'r';
    if (state.board[row][4] !== king) return;
    if (rights.K && state.board[row][7] === rook && !state.board[row][5] && !state.board[row][6] && !this.attacked(state.board, row, 5, enemy) && !this.attacked(state.board, row, 6, enemy)) moves.push({ fr: row, fc: 4, tr: row, tc: 6 });
    if (rights.Q && state.board[row][0] === rook && !state.board[row][1] && !state.board[row][2] && !state.board[row][3] && !this.attacked(state.board, row, 3, enemy) && !this.attacked(state.board, row, 2, enemy)) moves.push({ fr: row, fc: 4, tr: row, tc: 2 });
  }

  private applyBoardMove(state: ChessState, move: ChessMove): void {
    const piece = state.board[move.fr][move.fc] as string;
    const isEnPassant = piece.toLowerCase() === 'p' && state.enPassant?.r === move.tr && state.enPassant.c === move.tc && !state.board[move.tr][move.tc];
    state.board[move.fr][move.fc] = null;
    if (isEnPassant) state.board[move.fr][move.tc] = null;
    const promoted = move.promotion ? (piece === 'P' ? move.promotion.toUpperCase() : move.promotion) : piece;
    state.board[move.tr][move.tc] = promoted;
    if (piece === 'K' && move.fr === 7 && move.fc === 4 && move.tc === 6) { state.board[7][7] = null; state.board[7][5] = 'R'; }
    if (piece === 'K' && move.fr === 7 && move.fc === 4 && move.tc === 2) { state.board[7][0] = null; state.board[7][3] = 'R'; }
    if (piece === 'k' && move.fr === 0 && move.fc === 4 && move.tc === 6) { state.board[0][7] = null; state.board[0][5] = 'r'; }
    if (piece === 'k' && move.fr === 0 && move.fc === 4 && move.tc === 2) { state.board[0][0] = null; state.board[0][3] = 'r'; }
  }

  private updateCastlingRights(state: ChessState, piece: string, move: ChessMove, captured: string | null): void {
    if (piece === 'K') { state.castling.K = false; state.castling.Q = false; }
    if (piece === 'k') { state.castling.k = false; state.castling.q = false; }
    if (piece === 'R' && move.fr === 7 && move.fc === 0) state.castling.Q = false;
    if (piece === 'R' && move.fr === 7 && move.fc === 7) state.castling.K = false;
    if (piece === 'r' && move.fr === 0 && move.fc === 0) state.castling.q = false;
    if (piece === 'r' && move.fr === 0 && move.fc === 7) state.castling.k = false;
    if (captured === 'R' && move.tr === 7 && move.tc === 0) state.castling.Q = false;
    if (captured === 'R' && move.tr === 7 && move.tc === 7) state.castling.K = false;
    if (captured === 'r' && move.tr === 0 && move.tc === 0) state.castling.q = false;
    if (captured === 'r' && move.tr === 0 && move.tc === 7) state.castling.k = false;
  }

  private inCheck(board: (string | null)[][], color: 'w' | 'b'): boolean {
    const king = color === 'w' ? 'K' : 'k';
    for (let r = 0; r < 8; r += 1) for (let c = 0; c < 8; c += 1) if (board[r][c] === king) return this.attacked(board, r, c, color === 'w' ? 'b' : 'w');
    return true;
  }

  private attacked(board: (string | null)[][], r: number, c: number, by: 'w' | 'b'): boolean {
    const pawnRow = r + (by === 'w' ? 1 : -1);
    for (const dc of [-1, 1]) if (this.inside(pawnRow, c + dc) && board[pawnRow][c + dc] === (by === 'w' ? 'P' : 'p')) return true;
    for (const [dr, dc] of [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]]) if (this.inside(r + dr, c + dc) && board[r + dr][c + dc] === (by === 'w' ? 'N' : 'n')) return true;
    for (const [dr, dc] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      let nr = r + dr; let nc = c + dc;
      while (this.inside(nr, nc)) { const piece = board[nr][nc]; if (piece) { if (piece === (by === 'w' ? 'R' : 'r') || piece === (by === 'w' ? 'Q' : 'q')) return true; break; } nr += dr; nc += dc; }
    }
    for (const [dr, dc] of [[1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      let nr = r + dr; let nc = c + dc;
      while (this.inside(nr, nc)) { const piece = board[nr][nc]; if (piece) { if (piece === (by === 'w' ? 'B' : 'b') || piece === (by === 'w' ? 'Q' : 'q')) return true; break; } nr += dr; nc += dc; }
    }
    for (const [dr, dc] of [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]) if (this.inside(r + dr, c + dc) && board[r + dr][c + dc] === (by === 'w' ? 'K' : 'k')) return true;
    return false;
  }

  private insufficientMaterial(board: (string | null)[][]): boolean {
    const pieces: Array<{ piece: string; row: number; column: number }> = [];
    for (let row = 0; row < 8; row += 1) for (let column = 0; column < 8; column += 1) { const piece = board[row][column]; if (piece && piece.toLowerCase() !== 'k') pieces.push({ piece, row, column }); }
    if (pieces.some(({ piece }) => ['p', 'q', 'r'].includes(piece.toLowerCase()))) return false;
    if (pieces.length === 0 || pieces.length === 1) return true;
    if (pieces.every(({ piece }) => piece.toLowerCase() === 'b')) {
      const colors = new Set(pieces.map(({ row, column }) => (row + column) % 2));
      return colors.size === 1;
    }
    return false;
  }

  private positionKey(state: ChessState, turn: 'w' | 'b'): string {
    const board = state.board.map((row) => row.map((piece) => piece ?? '.').join('')).join('/');
    const rights = `${state.castling.K ? 'K' : ''}${state.castling.Q ? 'Q' : ''}${state.castling.k ? 'k' : ''}${state.castling.q ? 'q' : ''}` || '-';
    const enPassant = state.enPassant ? `${state.enPassant.r},${state.enPassant.c}` : '-';
    return `${board}|${turn}|${rights}|${enPassant}`;
  }

  private promotion(value: unknown): 'q' | 'r' | 'b' | 'n' | undefined {
    if (typeof value !== 'string') return undefined;
    const normalized = value.toLowerCase();
    return ['q', 'r', 'b', 'n'].includes(normalized) ? normalized as 'q' | 'r' | 'b' | 'n' : undefined;
  }

  private coord(row: unknown, column: unknown): { r: number; c: number } {
    return { r: asInt(row, 'row', 0, 7), c: asInt(column, 'column', 0, 7) };
  }

  private color(piece: string): 'w' | 'b' { return piece === piece.toUpperCase() ? 'w' : 'b'; }
  private inside(row: number, column: number): boolean { return row >= 0 && row < 8 && column >= 0 && column < 8; }
}
