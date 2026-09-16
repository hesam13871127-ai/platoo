import { ChessEngine, FourInARowEngine, MancalaEngine } from '../src/games/engines/board.engine';
import { CarromEngine, DominoesEngine, LudoEngine, PoolEngine } from '../src/games/engines/tabletop.engine';
import { MiniGolfEngine, TableSoccerEngine } from '../src/games/engines/sport.engine';
import { BingoEngine, SketchGuessEngine, TriviaBattleEngine, WerewolfEngine } from '../src/games/engines/party.engine';
import { OchoEngine } from '../src/games/engines/cards.engine';
import { GamePlayer } from '../src/games/game.types';
import { GameRegistry } from '../src/games/game.registry';

const players = (count: number): GamePlayer[] => Array.from({ length: count }, (_, seat) => ({ id: `player-${seat}`, seat, isBot: false }));

describe('authoritative game engines', () => {
  it('detects a four in a row win and rejects a full column', () => {
    const engine = new FourInARowEngine(); const roster = players(2); let state = engine.create(roster);
    for (const column of [0, 1, 0, 1, 0, 1, 0]) { const actor = state.turnPlayerId as string; state = engine.apply(state, actor, { type: 'drop', column }, roster); }
    expect(state.finished).toBe(true); expect(state.winnerId).toBe('player-0');
    expect(() => engine.apply(state, 'player-1', { type: 'drop', column: 0 }, roster)).toThrow();
  });

  it('starts chess with the legal opening move and rejects moving through a piece', () => {
    const engine = new ChessEngine(); const roster = players(2); let state = engine.create(roster);
    state = engine.apply(state, 'player-0', { type: 'move', fromRow: 6, fromCol: 4, toRow: 4, toCol: 4 }, roster);
    expect((state.board as unknown[][])[4][4]).toBe('P');
    expect(() => engine.apply(state, 'player-1', { type: 'move', fromRow: 0, fromCol: 0, toRow: 3, toCol: 0 }, roster)).toThrow();
  });

  it('supports castling, en passant, and promotion in chess', () => {
    const engine = new ChessEngine(); const roster = players(2); let state = engine.create(roster);
    const moves = [
      ['player-0', 6, 4, 4, 4], ['player-1', 1, 4, 3, 4],
      ['player-0', 7, 6, 5, 5], ['player-1', 0, 1, 2, 2],
      ['player-0', 7, 5, 4, 2], ['player-1', 0, 6, 2, 5],
      ['player-0', 7, 4, 7, 6],
    ] as const;
    for (const [actor, fromRow, fromCol, toRow, toCol] of moves) state = engine.apply(state, actor, { type: 'move', fromRow, fromCol, toRow, toCol }, roster) as any;
    expect((state as any).board[7][6]).toBe('K'); expect((state as any).board[7][5]).toBe('R'); expect((state as any).castling.K).toBe(false);

    state = engine.create(roster);
    for (const [actor, fromRow, fromCol, toRow, toCol] of [
      ['player-0', 6, 4, 4, 4], ['player-1', 1, 0, 2, 0], ['player-0', 4, 4, 3, 4], ['player-1', 1, 3, 3, 3],
    ] as const) state = engine.apply(state, actor, { type: 'move', fromRow, fromCol, toRow, toCol }, roster) as any;
    state = engine.apply(state, 'player-0', { type: 'move', fromRow: 3, fromCol: 4, toRow: 2, toCol: 3 }, roster) as any;
    expect((state as any).board[2][3]).toBe('P'); expect((state as any).board[3][3]).toBeNull();

    const promotion = engine.create(roster) as any;
    promotion.board = Array.from({ length: 8 }, () => Array(8).fill(null)); promotion.board[7][4] = 'K'; promotion.board[0][4] = 'k'; promotion.board[1][0] = 'P';
    promotion.turnPlayerId = 'player-0'; promotion.turnIndex = 0; promotion.castling = { K: false, Q: false, k: false, q: false }; promotion.positionCounts = {};
    const promoted = engine.apply(promotion, 'player-0', { type: 'move', fromRow: 1, fromCol: 0, toRow: 0, toCol: 0, promotion: 'n' }, roster) as any;
    expect(promoted.board[0][0]).toBe('N');
  });

  it('resolves chess checkmate and stalemate', () => {
    const engine = new ChessEngine(); const roster = players(2); let state = engine.create(roster);
    for (const [actor, fromRow, fromCol, toRow, toCol] of [
      ['player-0', 6, 5, 5, 5], ['player-1', 1, 4, 3, 4], ['player-0', 6, 6, 4, 6], ['player-1', 0, 3, 4, 7],
    ] as const) state = engine.apply(state, actor, { type: 'move', fromRow, fromCol, toRow, toCol }, roster) as any;
    expect((state as any).finished).toBe(true); expect((state as any).winnerId).toBe('player-1'); expect((state as any).draw).not.toBe(true);

    const stalemate = engine.create(roster) as any;
    stalemate.board = Array.from({ length: 8 }, () => Array(8).fill(null)); stalemate.board[0][0] = 'k'; stalemate.board[2][2] = 'K'; stalemate.board[1][2] = 'Q';
    stalemate.turnPlayerId = 'player-0'; stalemate.turnIndex = 0; stalemate.castling = { K: false, Q: false, k: false, q: false }; stalemate.positionCounts = {};
    const after = engine.apply(stalemate, 'player-0', { type: 'move', fromRow: 1, fromCol: 2, toRow: 2, toCol: 1 }, roster) as any;
    expect(after.finished).toBe(true); expect(after.draw).toBe(true); expect(after.drawReason).toBe('stalemate');

    let repetition = engine.create(roster) as any;
    const repetitionMoves = [
      ['player-0', 7, 6, 5, 5], ['player-1', 0, 6, 2, 5], ['player-0', 5, 5, 7, 6], ['player-1', 2, 5, 0, 6],
      ['player-0', 7, 6, 5, 5], ['player-1', 0, 6, 2, 5], ['player-0', 5, 5, 7, 6], ['player-1', 2, 5, 0, 6],
    ] as const;
    for (const [actor, fromRow, fromCol, toRow, toCol] of repetitionMoves) repetition = engine.apply(repetition, actor, { type: 'move', fromRow, fromCol, toRow, toCol }, roster) as any;
    expect(repetition.finished).toBe(true); expect(repetition.drawReason).toBe('threefold_repetition');

    const material = engine.create(roster) as any;
    material.board = Array.from({ length: 8 }, () => Array(8).fill(null)); material.board[7][4] = 'K'; material.board[0][4] = 'k'; material.board[7][1] = 'N';
    material.turnPlayerId = 'player-0'; material.turnIndex = 0; material.castling = { K: false, Q: false, k: false, q: false }; material.positionCounts = {};
    const materialDraw = engine.apply(material, 'player-0', { type: 'move', fromRow: 7, fromCol: 1, toRow: 5, toCol: 2 }, roster) as any;
    expect(materialDraw.finished).toBe(true); expect(materialDraw.drawReason).toBe('insufficient_material');
  });

  it('applies Ludo six-roll, capture, blockade, exact finish, and bot rules', () => {
    const engine = new LudoEngine(); const roster = players(2); let state = engine.create(roster) as any;
    state.pendingRoll = 6;
    state = engine.apply(state, 'player-0', { type: 'move', token: 0 }, roster) as any;
    expect(state.positions[0][0]).toBe(0); expect(state.turnPlayerId).toBe('player-0');
    state.pendingRoll = 1; state.positions[1][0] = 40;
    state = engine.apply(state, 'player-0', { type: 'move', token: 0 }, roster) as any;
    expect(state.positions[0][0]).toBe(1); expect(state.positions[1][0]).toBe(-1); expect(state.turnPlayerId).toBe('player-1');
    state.turnPlayerId = 'player-0'; state.turnIndex = 0; state.pendingRoll = 1; state.positions[0][0] = 0; state.positions[1][0] = 40; state.positions[1][1] = 40;
    expect(() => engine.apply(state, 'player-0', { type: 'move', token: 0 }, roster)).toThrow();
    state.positions[1][0] = -1; state.positions[1][1] = -1; state.positions[0][1] = 1; state.positions[0][2] = 1;
    expect(() => engine.apply(state, 'player-0', { type: 'move', token: 0 }, roster)).toThrow();
    state.positions[0][1] = -1; state.positions[0][2] = -1; state.positions[1][0] = 40; state.positions[1][1] = 40;
    expect(engine.botAction(state, 'player-0', roster).type).toBe('pass');
    const botState = engine.create(roster) as any; botState.pendingRoll = 6;
    expect(engine.botAction(botState, 'player-0', roster)).toEqual({ type: 'move', token: 0 });

    const finish = engine.create(roster) as any; finish.pendingRoll = 1; finish.positions[0] = [56, 57, 57, 57];
    const completed = engine.apply(finish, 'player-0', { type: 'move', token: 0 }, roster) as any;
    expect(completed.finished).toBe(true); expect(completed.winnerIds).toEqual(['player-0']);

    const teamRoster = players(4).map((player) => ({ ...player, team: player.seat % 2 }));
    const teamState = engine.create(teamRoster) as any; teamState.pendingRoll = 1; teamState.positions[0] = [56, 57, 57, 57]; teamState.positions[2] = [57, 57, 57, 57];
    const teamFinished = engine.apply(teamState, 'player-0', { type: 'move', token: 0 }, teamRoster) as any;
    expect(teamFinished.finished).toBe(true); expect(teamFinished.winnerIds).toEqual(['player-0', 'player-2']);

    const incompleteTeam = engine.create(teamRoster) as any;
    incompleteTeam.pendingRoll = 1; incompleteTeam.positions[0] = [56, 57, 57, 57]; incompleteTeam.positions[2] = [56, 57, 57, 57];
    const stillPlaying = engine.apply(incompleteTeam, 'player-0', { type: 'move', token: 0 }, teamRoster) as any;
    expect(stillPlaying.finished).toBe(false);
    expect(stillPlaying.winnerIds).toEqual([]);
  });

  it('plays pool 8-ball through groups, fouls, and the winning eight ball', () => {
    const engine = new PoolEngine(); const roster = players(2); let state = engine.create(roster) as any;
    state = engine.apply(state, 'player-0', { type: 'shot', power: 80, pocket: 0, pocketed: [1] }, roster) as any;
    expect(state.phase).toBe('open'); expect(state.turnPlayerId).toBe('player-0'); expect(state.remainingBalls).not.toContain(1);
    state = engine.apply(state, 'player-0', { type: 'shot', power: 60, pocket: 1, pocketed: [2] }, roster) as any;
    expect(state.groups).toEqual(['solids', 'stripes']);
    expect(() => engine.apply(state, 'player-0', { type: 'shot', power: 60, pocket: 1, pocketed: [9] }, roster)).toThrow();
    for (const ball of [3, 4, 5, 6, 7]) state = engine.apply(state, 'player-0', { type: 'shot', power: 60, pocket: 1, pocketed: [ball] }, roster) as any;
    expect(state.remainingBalls).toEqual([8, 9, 10, 11, 12, 13, 14, 15]);
    state = engine.apply(state, 'player-0', { type: 'shot', power: 70, pocket: 2, pocketed: [8] }, roster) as any;
    expect(state.finished).toBe(true); expect(state.winnerId).toBe('player-0');

    const earlyEight = engine.create(roster) as any;
    earlyEight.phase = 'assigned'; earlyEight.groups = ['solids', 'stripes']; earlyEight.remainingBalls = [3, 8, 9];
    const foul = engine.apply(earlyEight, 'player-0', { type: 'shot', power: 70, pocket: 2, pocketed: [8] }, roster) as any;
    expect(foul.finished).toBe(true); expect(foul.winnerId).toBe('player-1');

    const scratch = engine.create(roster) as any;
    const afterScratch = engine.apply(scratch, 'player-0', { type: 'shot', power: 35, pocket: 0, pocketed: [], scratch: true }, roster) as any;
    expect(afterScratch.phase).toBe('open'); expect(afterScratch.turnPlayerId).toBe('player-1');
  });

  it('lets pool bots complete full matches', () => {
    const engine = new PoolEngine(); const roster = players(2).map((player) => ({ ...player, isBot: true }));
    for (let trial = 0; trial < 10; trial += 1) {
      let state = engine.create(roster) as any;
      for (let move = 0; move < 100 && !state.finished; move += 1) {
        const actor = state.turnPlayerId as string;
        state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster) as any;
      }
      expect(state.finished).toBe(true); expect(state.winnerId).toBeTruthy();
    }
  });

  it('runs Werewolf night roles, private seer information, voting, and victory rules', () => {
    const engine = new WerewolfEngine(); const roster = players(7); const created = engine.create(roster) as any;
    expect(created.roles.filter((role: string) => role === 'werewolf')).toHaveLength(1);
    expect(created.roles.filter((role: string) => role === 'seer')).toHaveLength(1);
    expect(created.roles.filter((role: string) => role === 'doctor')).toHaveLength(1);

    const state = created as any;
    state.roles = ['werewolf', 'villager', 'villager', 'seer', 'doctor', 'villager', 'villager'];
    state.alive = Array(7).fill(true); state.phase = 'night'; state.nightTargets = Array(7).fill(null); state.nightActed = Array(7).fill(false); state.votes = Array(7).fill(null); state.turnIndex = 0; state.turnPlayerId = 'player-0'; state.seerResults = Array(7).fill(null);
    let next = engine.apply(state, 'player-0', { type: 'night', target: 1 }, roster) as any;
    expect(() => engine.apply(next, 'player-2', { type: 'night' }, roster)).toThrow();
    next = engine.apply(next, 'player-1', { type: 'night' }, roster) as any;
    next = engine.apply(next, 'player-2', { type: 'night' }, roster) as any;
    next = engine.apply(next, 'player-3', { type: 'night', target: 0 }, roster) as any;
    next = engine.apply(next, 'player-4', { type: 'night', target: 1 }, roster) as any;
    next = engine.apply(next, 'player-5', { type: 'night' }, roster) as any;
    next = engine.apply(next, 'player-6', { type: 'night' }, roster) as any;
    expect(next.phase).toBe('day'); expect(next.alive[1]).toBe(true); expect(next.seerResults[3]).toEqual({ target: 0, isWerewolf: true });
    for (const [actor, target] of [['player-0', 1], ['player-1', 0], ['player-2', 0], ['player-3', 0], ['player-4', 0], ['player-5', 0], ['player-6', 0]] as const) next = engine.apply(next, actor, { type: 'vote', target }, roster) as any;
    expect(next.finished).toBe(true); expect(next.winnerIds).not.toContain('player-0'); expect(next.alive[1]).toBe(true);
    expect(engine.outcome(next, roster).loserIds).toContain('player-0');
  });

  it('lets Werewolf bots resolve complete matches', () => {
    const engine = new WerewolfEngine(); const roster = players(7).map((player) => ({ ...player, isBot: true }));
    for (let trial = 0; trial < 10; trial += 1) {
      let state = engine.create(roster) as any;
      for (let move = 0; move < 500 && !state.finished; move += 1) {
        const actor = state.turnPlayerId as string;
        state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster) as any;
      }
      expect(state.finished).toBe(true); expect(state.winnerIds.length).toBeGreaterThan(0);
    }
  });

  it('plays Mini Golf hole-by-hole and settles the lowest total score, including a tie', () => {
    const engine = new MiniGolfEngine(); const roster = players(2); let state = engine.create(roster) as any;
    expect(() => engine.apply(state, 'player-0', { type: 'putt', strokes: 0 }, roster)).toThrow();
    for (let hole = 1; hole <= 9; hole += 1) {
      state = engine.apply(state, state.turnPlayerId, { type: 'putt', strokes: 2 }, roster) as any;
      state = engine.apply(state, state.turnPlayerId, { type: 'putt', strokes: 3 }, roster) as any;
      expect(state.holeStrokes).toEqual(hole === 9 && state.finished ? [2, 3] : [null, null]);
    }
    expect(state.finished).toBe(true); expect(state.completedHoles).toBe(9); expect(state.winnerIds).toEqual(['player-0']);
    expect(() => engine.apply(state, 'player-0', { type: 'putt', strokes: 2 }, roster)).toThrow();
    expect(engine.outcome(state, roster)).toMatchObject({ finished: true, winnerIds: ['player-0'], loserIds: ['player-1'], draw: false });

    let tie = engine.create(roster) as any;
    for (let hole = 1; hole <= 9; hole += 1) {
      tie = engine.apply(tie, tie.turnPlayerId, { type: 'putt', strokes: 2 }, roster) as any;
      tie = engine.apply(tie, tie.turnPlayerId, { type: 'putt', strokes: 2 }, roster) as any;
    }
    expect(tie.finished).toBe(true); expect(tie.winnerIds).toEqual(['player-0', 'player-1']); expect(tie.draw).toBe(true);
  });

  it('uses Table Soccer target goals, validates shots, and resolves a four-player team win', () => {
    const engine = new TableSoccerEngine(); const roster = players(4).map((player) => ({ ...player, team: player.seat % 2 })); let state = engine.create(roster) as any;
    expect(state.teamMode).toBe(true); expect(state.teamGoals).toEqual([0, 0]);
    expect(() => engine.apply(state, 'player-0', { type: 'shoot', power: 101, aim: 50 }, roster)).toThrow();
    state.teamGoals = [4, 0]; state.goals = [4, 0, 0, 0]; state.turnPlayerId = 'player-0'; state.turnIndex = 0;
    for (let attempts = 0; attempts < 100 && !state.finished; attempts += 1) state = engine.apply(state, state.turnPlayerId, engine.botAction(state, state.turnPlayerId, roster), roster) as any;
    expect(state.finished).toBe(true); expect(state.winnerIds).toEqual(['player-0', 'player-2']);
    expect(engine.outcome(state, roster).loserIds).toEqual(['player-1', 'player-3']);
  });

  it('runs Sketch & Guess rounds, scores the drawer and guesser, and lets bots finish', () => {
    const engine = new SketchGuessEngine(); const roster = players(3); let state = engine.create(roster) as any;
    expect(() => engine.apply(state, 'player-0', { type: 'guess', guess: 'anything' }, roster)).toThrow();
    const submitted = engine.apply(state, 'player-0', engine.botAction(state, 'player-0'), roster) as any;
    expect(() => engine.apply(submitted, 'player-1', { type: 'guess', guess: '   ' }, roster)).toThrow();
    expect(() => engine.apply(submitted, 'player-2', { type: 'guess', guess: submitted.prompt }, roster)).toThrow();
    state = submitted;
    for (let move = 0; move < 20 && !state.finished; move += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state, actor), roster) as any;
    }
    expect(state.finished).toBe(true); expect(state.winnerIds.length).toBeGreaterThan(0); expect(state.scores.every((score: number) => score > 0)).toBe(true);
    expect(() => engine.apply(state, 'player-0', { type: 'guess', guess: 'late' }, roster)).toThrow();
  });

  it('runs Trivia Battle rounds, hides invalid answers, and settles a complete bot match', () => {
    const engine = new TriviaBattleEngine(); const roster = players(2); let state = engine.create(roster) as any;
    expect(() => engine.apply(state, 'player-0', { type: 'answer', answer: 4 }, roster)).toThrow();
    for (let move = 0; move < 30 && !state.finished; move += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster) as any;
    }
    expect(state.finished).toBe(true); expect(state.scores).toEqual([1000, 1000]); expect(state.winnerIds).toEqual(['player-0', 'player-1']); expect(state.draw).toBe(true);
    expect(engine.outcome(state, roster)).toMatchObject({ finished: true, draw: true });
  });

  it('gives the second mancala player a turn after a non-store finish', () => {
    const engine = new MancalaEngine(); const roster = players(2); const state = engine.create(roster);
    const next = engine.apply(state, 'player-0', { type: 'sow', pit: 0 }, roster);
    expect(next.turnPlayerId).toBe('player-1');
    expect((next.pits as number[][])[0].reduce((sum, value) => sum + value, 0)).toBeGreaterThan(0);
  });

  it('registers every shipped game with an isolated initial state', () => {
    const registry = new GameRegistry();
    expect(registry.list()).toHaveLength(28);
    for (const descriptor of registry.list()) {
      const roster = players(descriptor.minPlayers);
      const state = registry.engine(descriptor.id).create(roster);
      expect(state).toBeDefined();
      expect(typeof state.turnPlayerId === 'string' || state.phase === 'placing').toBe(true);
    }
  });

  it('only permits an Ocho card matching the active color or value', () => {
    const engine = new OchoEngine(); const roster = players(2); const state = engine.create(roster); const hand = (state.hands as Array<Array<{ color: string; value: string }>>)[0];
    (state as any).discard = [{ color: 'red', value: '9' }]; (state as any).currentColor = 'red'; (state as any).turnPlayerId = 'player-0';
    (state as any).pendingDraw = 0; (state as any).drawnCardIndex = null; (state as any).awaitingColor = false;
    hand[0] = { color: 'red', value: '0' }; hand[1] = { color: 'blue', value: '0' };
    expect(() => engine.apply(state, 'player-0', { type: 'play', index: 0 }, roster)).not.toThrow();
    expect(() => engine.apply(state, 'player-0', { type: 'play', index: 1 }, roster)).toThrow();
  });

  it('applies Ocho opening draw penalties and wild-color turns', () => {
    const engine = new OchoEngine(); const roster = players(3); const drawTwo = engine.create(roster) as any;
    drawTwo.pendingDraw = 0; drawTwo.pendingDrawSource = null; drawTwo.turnIndex = 0; drawTwo.turnPlayerId = 'player-0';
    (engine as any).applyOpeningCard(drawTwo, { color: 'red', value: 'draw2' }, roster);
    expect(drawTwo.pendingDraw).toBe(2);
    expect(drawTwo.turnIndex).toBe(1);
    expect(drawTwo.turnPlayerId).toBe('player-1');

    const wild = engine.create(roster) as any;
    wild.awaitingColor = true; wild.currentColor = ''; wild.turnIndex = 0; wild.turnPlayerId = 'player-0'; wild.direction = 1;
    const chosen = engine.apply(wild, 'player-0', { type: 'choose_color', color: 'blue' }, roster) as any;
    expect(chosen.currentColor).toBe('blue');
    expect(chosen.awaitingColor).toBe(false);
    expect(chosen.turnIndex).toBe(1);
    expect(chosen.turnPlayerId).toBe('player-1');
  });

  it('deals the complete 108-card deck and keeps Wild Draw Four out of the opening discard', () => {
    const state = new OchoEngine().create(players(4)) as any;
    const cardCount = state.hands.flat().length + state.draw.length + state.discard.length;
    expect(cardCount).toBe(108);
    expect(state.discard[state.discard.length - 1].value).not.toBe('wild4');
  });

  it('lets a player play a matching card drawn during the same turn', () => {
    const engine = new OchoEngine(); const roster = players(2);
    const state = {
      hands: [[{ color: 'red', value: '1' }], [{ color: 'blue', value: '2' }]],
      draw: [{ color: 'green', value: '7' }], discard: [{ color: 'red', value: '7' }], currentColor: 'red', direction: 1,
      turnIndex: 0, turnPlayerId: 'player-0', winnerId: null, finished: false, pendingDraw: 0,
      pendingDrawSource: null, wildFourLegal: null, drawnCardIndex: null, awaitingColor: false,
    } as any;
    const drawn = engine.apply(state, 'player-0', { type: 'draw' }, roster) as any;
    expect(drawn.turnPlayerId).toBe('player-0');
    expect(drawn.drawnCardIndex).toBe(1);
    const passed = engine.apply(drawn, 'player-0', { type: 'pass' }, roster) as any;
    expect(passed.turnPlayerId).toBe('player-1');
    const redrawn = engine.apply(state, 'player-0', { type: 'draw' }, roster) as any;
    const played = engine.apply(redrawn, 'player-0', { type: 'play', index: 1, call: true }, roster) as any;
    expect(played.discard.at(-1)).toEqual({ color: 'green', value: '7' });
    expect(played.turnPlayerId).toBe('player-1');
  });

  it('resolves a successful Wild Draw Four challenge correctly', () => {
    const engine = new OchoEngine(); const roster = players(2);
    const state = {
      hands: [[{ color: 'yellow', value: '5' }, { color: 'wild', value: 'wild4' }], [{ color: 'blue', value: '2' }]],
      draw: Array.from({ length: 12 }, () => ({ color: 'green', value: '1' })), discard: [{ color: 'yellow', value: '9' }], currentColor: 'yellow', direction: 1,
      turnIndex: 0, turnPlayerId: 'player-0', winnerId: null, finished: false, pendingDraw: 0,
      pendingDrawSource: null, wildFourLegal: null, drawnCardIndex: null, awaitingColor: false,
    } as any;
    const played = engine.apply(state, 'player-0', { type: 'play', index: 1, color: 'blue', call: true }, roster) as any;
    expect(played.pendingDraw).toBe(4);
    expect(played.wildFourLegal).toBe(false);
    const challenged = engine.apply(played, 'player-1', { type: 'challenge' }, roster) as any;
    expect(challenged.hands[0]).toHaveLength(5);
    expect(challenged.turnPlayerId).toBe('player-1');
    expect(challenged.pendingDraw).toBe(0);
  });

  it('lets the Ocho bot action loop finish complete matches', () => {
    const engine = new OchoEngine(); const roster = players(2).map((player) => ({ ...player, isBot: true }));
    for (let trial = 0; trial < 10; trial += 1) {
      let state = engine.create(roster) as any;
      for (let move = 0; move < 5000 && !state.finished; move += 1) {
        const actor = state.turnPlayerId as string;
        state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster) as any;
      }
      expect(state.finished).toBe(true);
    }
  });

  it('draws authoritative Bingo numbers, marks cards, and resolves multiple winners', () => {
    const engine = new BingoEngine(); const roster = players(2); const state = engine.create(roster) as any;
    expect(state.cards[0].marked[12]).toBe(true);
    expect(() => engine.apply(state, 'player-0', { type: 'call', number: state.cards[0].values[0] }, roster)).toThrow();
    state.cards[0].marked = Array(25).fill(true); state.cards[0].marked[0] = false; state.cards[0].values[0] = 7;
    state.cards[1].marked = Array(25).fill(false); state.cards[1].marked[12] = true; for (const index of [0, 1, 2, 3, 4]) state.cards[1].marked[index] = index !== 0; state.cards[1].values[0] = 7;
    state.bag = [7]; state.called = []; state.lastNumber = null; state.turnPlayerId = 'player-0'; state.turnIndex = 0;
    const finished = engine.apply(state, 'player-0', { type: 'draw' }, roster) as any;
    expect(finished.called).toEqual([7]); expect(finished.cards[0].marked[0]).toBe(true);
    expect(finished.finished).toBe(true); expect(finished.winnerIds).toEqual(['player-0', 'player-1']); expect(finished.draw).toBe(true);
  });

  it('lets Bingo bot turns consume the cage and settle a match', () => {
    const engine = new BingoEngine(); const roster = players(4).map((player) => ({ ...player, isBot: true }));
    let state = engine.create(roster) as any;
    for (let move = 0; move < 100 && !state.finished; move += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster) as any;
    }
    expect(state.finished).toBe(true); expect(state.called.length).toBeGreaterThan(0); expect(state.winnerIds.length).toBeGreaterThan(0);
  });

  it('enforces Dominoes opening, legal end placement, draw-until-playable, and blocked scoring', () => {
    const engine = new DominoesEngine(); const roster = players(2); const created = engine.create(roster) as any;
    expect(created.chain).toHaveLength(2); expect(created.handSizes.reduce((sum: number, size: number) => sum + size, 0)).toBe(13); expect(created.boneyard).toHaveLength(14);

    const placement = engine.create(roster) as any;
    placement.hands = [[[3, 5]], [[6, 6]]]; placement.handSizes = [1, 1]; placement.chain = [3, 4]; placement.boneyard = []; placement.turnIndex = 0; placement.turnPlayerId = 'player-0';
    expect(() => engine.apply(placement, 'player-0', { type: 'play', index: 0, side: 'right' }, roster)).toThrow();
    const placed = engine.apply(placement, 'player-0', { type: 'play', index: 0, side: 'left' }, roster) as any;
    expect(placed.chain).toEqual([5, 3, 4]); expect(placed.winnerIds).toEqual(['player-0']);

    const blocked = engine.create(roster) as any;
    blocked.hands = [[[6, 6]], [[0, 0]]]; blocked.handSizes = [1, 1]; blocked.chain = [1, 2]; blocked.boneyard = [[3, 3]]; blocked.passCount = 0; blocked.turnIndex = 0; blocked.turnPlayerId = 'player-0';
    const drawn = engine.apply(blocked, 'player-0', { type: 'draw' }, roster) as any;
    expect(drawn.turnPlayerId).toBe('player-0'); expect(drawn.lastDrawn).toEqual([3, 3]);
    const passed = engine.apply(drawn, 'player-0', { type: 'pass' }, roster) as any;
    const finished = engine.apply(passed, 'player-1', { type: 'pass' }, roster) as any;
    expect(finished.finished).toBe(true); expect(finished.winnerIds).toEqual(['player-1']);
  });

  it('lets Dominoes bot actions finish complete matches', () => {
    const engine = new DominoesEngine(); const roster = players(2).map((player) => ({ ...player, isBot: true }));
    for (let trial = 0; trial < 10; trial += 1) {
      let state = engine.create(roster) as any;
      for (let move = 0; move < 1000 && !state.finished; move += 1) {
        const actor = state.turnPlayerId as string;
        state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster) as any;
      }
      expect(state.finished).toBe(true); expect(state.winnerIds.length).toBeGreaterThan(0);
    }
  });

  it('assigns Carrom colors and requires a covered queen before winning', () => {
    const engine = new CarromEngine(); const roster = players(2); let state = engine.create(roster) as any;
    state = engine.apply(state, 'player-0', { type: 'strike', power: 70, pocketed: [1], queen: false }, roster) as any;
    expect(state.groups).toEqual(['white', 'black']); expect(state.scores[0]).toBe(1); expect(state.turnPlayerId).toBe('player-0');
    const open = engine.create(roster) as any;
    expect(() => engine.apply(open, 'player-0', { type: 'strike', power: 70, pocketed: [1, 10], queen: false }, roster)).toThrow('one coin color');
    expect(() => engine.apply(state, 'player-0', { type: 'strike', power: 70, pocketed: [10], queen: false }, roster)).toThrow();
    state = engine.apply(state, 'player-0', { type: 'strike', power: 40, pocketed: [], queen: false }, roster) as any;
    expect(state.turnPlayerId).toBe('player-1');
    state.turnIndex = 0; state.turnPlayerId = 'player-0';
    const foul = engine.apply(state, 'player-0', { type: 'strike', power: 20, pocketed: [], queen: false, foul: true }, roster) as any;
    expect(foul.remainingCoins).toContain(1); expect(foul.scores[0]).toBe(0); expect(foul.turnPlayerId).toBe('player-1'); expect(foul.lastShot.foul).toBe(true);

    const queen = engine.create(roster) as any;
    queen.groups = ['white', 'black']; queen.remainingCoins = [1, 10]; queen.turnIndex = 0; queen.turnPlayerId = 'player-0';
    const called = engine.apply(queen, 'player-0', { type: 'strike', power: 70, pocketed: [1], queen: true }, roster) as any;
    expect(called.queenRemaining).toBe(false); expect(called.queenPendingFor).toBeNull(); expect(called.finished).toBe(true); expect(called.winnerIds).toEqual(['player-0']);
  });

  it('lets Carrom bot actions finish complete matches', () => {
    const engine = new CarromEngine(); const roster = players(2).map((player) => ({ ...player, isBot: true }));
    for (let trial = 0; trial < 10; trial += 1) {
      let state = engine.create(roster) as any;
      for (let move = 0; move < 1000 && !state.finished; move += 1) {
        const actor = state.turnPlayerId as string;
        state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster) as any;
      }
      expect(state.finished).toBe(true); expect(state.winnerIds.length).toBeGreaterThan(0);
    }
  });

  it('lets the Four in a Row bot action loop finish complete matches', () => {
    const engine = new FourInARowEngine(); const roster = players(2).map((player) => ({ ...player, isBot: true }));
    for (let trial = 0; trial < 10; trial += 1) {
      let state = engine.create(roster) as any;
      for (let move = 0; move < 100 && !state.finished; move += 1) {
        const actor = state.turnPlayerId as string;
        state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster) as any;
      }
      expect(state.finished).toBe(true);
    }
  });

  it('lets Ludo and Chess bot turns reach an authoritative terminal state', () => {
    const ludo = new LudoEngine(); const ludoRoster = players(4).map((player) => ({ ...player, isBot: true, team: player.seat % 2 }));
    for (let trial = 0; trial < 3; trial += 1) {
      let state = ludo.create(ludoRoster) as any;
      for (let move = 0; move < 2500 && !state.finished; move += 1) {
        const actor = state.turnPlayerId as string;
        state = ludo.apply(state, actor, ludo.botAction(state, actor, ludoRoster), ludoRoster) as any;
      }
      expect(state.finished).toBe(true);
    }

    const chess = new ChessEngine(); const chessRoster = players(2).map((player) => ({ ...player, isBot: true }));
    for (let trial = 0; trial < 3; trial += 1) {
      let state = chess.create(chessRoster) as any;
      for (let move = 0; move < 2000 && !state.finished; move += 1) {
        const actor = state.turnPlayerId as string;
        state = chess.apply(state, actor, chess.botAction(state, actor, chessRoster), chessRoster) as any;
      }
      expect(state.finished).toBe(true);
    }
  });
});
