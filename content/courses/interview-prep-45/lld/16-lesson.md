---
kind: lesson
id_key: interview-prep-45/lld-16-games
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "LLD: Games — Tic-Tac-Toe, Snake & Ladder, Chess"
position: 16
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

Games are asked because they compress a lot of design into a small domain: a board, players, turns, rules, and a win condition. Three of them, in increasing difficulty, cover the whole spectrum — Tic-Tac-Toe tests whether you can find the O(1) win check, Snake & Ladder tests clean turn/state modelling, and Chess tests polymorphic rules and extensibility.

The shared skeleton for every board game, worth stating before you write a class:

```
Game        owns the board, the player order, the turn, and the status
Board       owns cells and geometry (is this position valid?)
Player      identity + a strategy for choosing a move (human / bot)
Move        a value object: what was attempted
Rules       validate a move and detect the terminal condition
GameStatus  IN_PROGRESS | WON | DRAW | ABANDONED
```

## Tic-Tac-Toe — the O(1) win check

**The design point is not the classes; it is the win detection.** Rescanning the whole board after every move is O(n²). Instead keep running sums per row, per column, and for both diagonals: player 1 adds +1, player 2 adds −1, and a win is the instant any counter reaches ±n. Each move touches one row, one column, and at most both diagonals — so the check is O(1).

```python
class TicTacToe:
    """O(1) per move: running counters instead of rescanning the board."""

    def __init__(self, n: int = 3):
        self.n = n
        self._rows = [0] * n
        self._cols = [0] * n
        self._diag = 0
        self._anti = 0
        self._board = [[0] * n for _ in range(n)]
        self._moves = 0

    def move(self, row: int, col: int, player: int) -> str:
        if not (0 <= row < self.n and 0 <= col < self.n):
            raise ValueError("off the board")
        if self._board[row][col] != 0:
            raise ValueError("cell already taken")
        if player not in (1, 2):
            raise ValueError("unknown player")

        delta = 1 if player == 1 else -1
        self._board[row][col] = player
        self._moves += 1

        self._rows[row] += delta
        self._cols[col] += delta
        if row == col:
            self._diag += delta
        if row + col == self.n - 1:          # NOT elif: the centre of an odd board is both
            self._anti += delta

        if self.n in (abs(self._rows[row]), abs(self._cols[col]),
                      abs(self._diag), abs(self._anti)):
            return f"player {player} wins"
        return "draw" if self._moves == self.n * self.n else "in progress"


game = TicTacToe(3)
assert game.move(0, 0, 1) == "in progress"
assert game.move(1, 1, 2) == "in progress"
assert game.move(0, 1, 1) == "in progress"
assert game.move(2, 2, 2) == "in progress"
assert game.move(0, 2, 1) == "player 1 wins"          # top row complete

try:
    game.move(0, 0, 2)
    raise AssertionError("re-using a cell was allowed")
except ValueError as e:
    print("rejected:", e)

# X O X
# X O O   -- no line completes, so a full board is a draw
# O X X
draw = TicTacToe(3)
for r, c, p in [(0,0,1),(0,1,2),(0,2,1),(1,1,2),(1,0,1),(1,2,2),(2,1,1),(2,0,2),(2,2,1)]:
    result = draw.move(r, c, p)
assert result == "draw"
print("full board result:", result)
```

Two details that get probed: the diagonal checks use `if`/`if`, **not** `if`/`elif`, because the centre cell of an odd board sits on both diagonals; and a draw is detected by move count, not by scanning for empty cells.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-16-ttt-q1", "type": "mcq",
      "prompt": "Why do the two diagonal updates use separate `if` statements rather than `if`/`elif`?",
      "options": [
        {"id":"a","text":"Because `elif` is slower"},
        {"id":"b","text":"On an odd-sized board the centre cell satisfies both `row == col` and `row + col == n-1`, so it lies on both diagonals and must update both counters"},
        {"id":"c","text":"Because the anti-diagonal counter must always be updated"},
        {"id":"d","text":"Because the board may be non-square"}
      ],
      "correct": "b",
      "explanation": "For n=3 the centre (1,1) is on both diagonals. `elif` would skip the anti-diagonal update there, making a diagonal win through the centre undetectable." }
] }
```

## Snake & Ladder — clean turn and state modelling

There is no clever algorithm here; the problem is asked to see whether you model **turns, rules, and termination** cleanly, and whether you handle the edge cases.

| Rule question | Typical answer | Where it lives |
|---|---|---|
| Overshoot the final square? | Stay put (or bounce back) — a rule, not an accident | `MovementRule` |
| Roll a six? | Roll again | Turn loop |
| Three consecutive sixes? | Turn forfeited | Turn loop |
| Must you land exactly on 100? | Yes | `MovementRule` |
| Can a snake head also be a ladder bottom? | No — validate the board at construction | `Board` invariant |
| Dice count | Configurable (one or two) | `Dice` strategy |

Modelling snakes and ladders as a single `jumps: {start: end}` map is the simplification worth making out loud: a snake is a jump to a lower square and a ladder a jump to a higher one, so one lookup handles both and validation ("no square is both a start and an end") is trivial.

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum


class Status(Enum):
    IN_PROGRESS = "in_progress"
    WON = "won"


class Dice(ABC):
    @abstractmethod
    def roll(self) -> int: ...


class ScriptedDice(Dice):
    """Deterministic dice: the same seam a real design uses for a RandomDice."""
    def __init__(self, values: list[int]): self._values, self._i = values, 0
    def roll(self) -> int:
        value = self._values[self._i % len(self._values)]
        self._i += 1
        return value


@dataclass
class Board:
    size: int
    jumps: dict[int, int] = field(default_factory=dict)   # snake OR ladder

    def __post_init__(self):
        for start, end in self.jumps.items():
            if not (1 <= start <= self.size and 1 <= end <= self.size):
                raise ValueError(f"jump {start}->{end} is off the board")
            if end in self.jumps:                         # forbids chained jumps
                raise ValueError(f"square {end} is both a destination and a jump start")
        if self.size in self.jumps:
            raise ValueError("the final square cannot start a jump")

    def destination(self, square: int) -> int:
        return self.jumps.get(square, square)


@dataclass
class Player:
    name: str
    position: int = 0


class Game:
    MAX_SIXES = 3

    def __init__(self, board: Board, players: list[Player], dice: Dice):
        if len(players) < 2:
            raise ValueError("need at least two players")
        self.board, self.players, self.dice = board, players, dice
        self.turn = 0
        self.status = Status.IN_PROGRESS
        self.winner: Player | None = None
        self.log: list[str] = []

    def current_player(self) -> Player:
        return self.players[self.turn % len(self.players)]

    def play_turn(self) -> str:
        if self.status is Status.WON:
            raise RuntimeError("game is over")

        player = self.current_player()
        sixes = 0
        while True:
            roll = self.dice.roll()
            if roll == 6:
                sixes += 1
                if sixes == self.MAX_SIXES:
                    self.log.append(f"{player.name}: three sixes, turn forfeited")
                    break
            target = player.position + roll
            if target > self.board.size:
                self.log.append(f"{player.name}: rolled {roll}, overshoot, stays at {player.position}")
                break                                   # must land exactly on the last square
            landed = self.board.destination(target)
            kind = "" if landed == target else (" ladder" if landed > target else " snake")
            player.position = landed
            self.log.append(f"{player.name}: rolled {roll} -> {landed}{kind}")
            if landed == self.board.size:
                self.status, self.winner = Status.WON, player
                self.turn += 1
                return f"{player.name} wins"
            if roll != 6:
                break                                   # a six earns another roll
        self.turn += 1
        return "in progress"


board = Board(size=20, jumps={3: 15, 17: 5})            # ladder 3->15, snake 17->5
alice, bob = Player("alice"), Player("bob")
# alice: 3 (ladder to 15) ... bob: 5 ... alice: 6 then 6 -> overshoot handling
game = Game(board, [alice, bob], ScriptedDice([3, 5, 2, 4, 3, 6, 4, 1]))

assert game.play_turn() == "in progress"
assert alice.position == 15                              # ladder taken
game.play_turn(); assert bob.position == 5               # rolled 5
game.play_turn()                                         # alice: 15 + 2 = 17, snake to 5
assert alice.position == 5 and game.log[-1].endswith("snake")

# Landing exactly on the final square wins.
sprint = Game(Board(size=10), [Player("a"), Player("b")], ScriptedDice([5, 1, 5]))
sprint.play_turn()                                       # a -> 5
sprint.play_turn()                                       # b -> 1
assert sprint.play_turn() == "a wins"                    # a: 5 + 5 = 10
assert sprint.status is Status.WON and sprint.winner.name == "a"

print("\n".join(game.log))
print("sprint winner:", sprint.winner.name)
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-16-snl-q1", "type": "mcq",
      "prompt": "Why model snakes and ladders as a single `jumps: {start: end}` map rather than two separate collections?",
      "options": [
        {"id":"a","text":"It uses less memory"},
        {"id":"b","text":"They are the same mechanic — a jump to a different square — differing only in direction, so one lookup handles both and board validation (no square is both a jump start and a destination) becomes a single check"},
        {"id":"c","text":"Because ladders must be processed before snakes"},
        {"id":"d","text":"Because a player can only use each ladder once"}
      ],
      "correct": "b",
      "explanation": "Recognising that two named domain concepts share one mechanic is the modelling insight. The direction is derivable (`end > start` is a ladder), so it does not need to be encoded in the structure." }
] }
```

## Chess — polymorphic rules and extensibility

Chess is the hard one, and nobody expects a complete implementation in 45 minutes. What is expected is the **shape**: an extensible piece hierarchy, move validation split from move execution, and a plan for the special rules.

**The core decision: each piece owns its own movement rule.** This is polymorphism doing exactly what it exists for — adding a new piece type (a fairy-chess variant, a custom game) means one new class and zero edits.

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum


class Colour(Enum):
    WHITE = "w"
    BLACK = "b"


@dataclass(frozen=True)
class Square:                                   # value object
    row: int
    col: int
    def valid(self) -> bool: return 0 <= self.row < 8 and 0 <= self.col < 8


class Piece(ABC):
    def __init__(self, colour: Colour): self.colour, self.has_moved = colour, False

    @abstractmethod
    def symbol(self) -> str: ...

    @abstractmethod
    def can_move(self, src: Square, dst: Square, board: "Board") -> bool:
        """Geometry only. Path blocking and check legality are the board's job."""

    def path_clear(self, src: Square, dst: Square, board: "Board") -> bool:
        step_r = (dst.row > src.row) - (dst.row < src.row)      # sign: -1, 0, or 1
        step_c = (dst.col > src.col) - (dst.col < src.col)
        r, c = src.row + step_r, src.col + step_c
        while (r, c) != (dst.row, dst.col):
            if board.at(Square(r, c)) is not None:
                return False
            r, c = r + step_r, c + step_c
        return True


class Rook(Piece):
    def symbol(self): return "R"
    def can_move(self, src, dst, board):
        if src.row != dst.row and src.col != dst.col:
            return False
        return self.path_clear(src, dst, board)


class Bishop(Piece):
    def symbol(self): return "B"
    def can_move(self, src, dst, board):
        if abs(src.row - dst.row) != abs(src.col - dst.col):
            return False
        return self.path_clear(src, dst, board)


class Queen(Piece):
    def symbol(self): return "Q"
    def can_move(self, src, dst, board):
        straight = src.row == dst.row or src.col == dst.col
        diagonal = abs(src.row - dst.row) == abs(src.col - dst.col)
        return (straight or diagonal) and self.path_clear(src, dst, board)


class Knight(Piece):
    def symbol(self): return "N"
    def can_move(self, src, dst, board):        # jumps: never checks the path
        return {abs(src.row - dst.row), abs(src.col - dst.col)} == {1, 2}


class King(Piece):
    def symbol(self): return "K"
    def can_move(self, src, dst, board):
        return max(abs(src.row - dst.row), abs(src.col - dst.col)) == 1


class Pawn(Piece):
    def symbol(self): return "P"
    def can_move(self, src, dst, board):
        direction = -1 if self.colour is Colour.WHITE else 1   # white moves up the array
        forward = dst.row - src.row
        sideways = abs(dst.col - src.col)
        target = board.at(dst)
        if sideways == 0 and target is None:                    # straight push
            if forward == direction:
                return True
            return (forward == 2 * direction and not self.has_moved
                    and board.at(Square(src.row + direction, src.col)) is None)
        if sideways == 1 and forward == direction:              # diagonal capture only
            return target is not None and target.colour is not self.colour
        return False


class Board:
    def __init__(self):
        self._grid: dict[tuple[int, int], Piece] = {}

    def place(self, piece: Piece, square: Square) -> None:
        self._grid[(square.row, square.col)] = piece

    def at(self, square: Square) -> Piece | None:
        return self._grid.get((square.row, square.col))

    def move(self, src: Square, dst: Square, turn: Colour) -> str:
        """Validation order matters: ownership → geometry → destination → self-check."""
        if not (src.valid() and dst.valid()) or src == dst:
            raise ValueError("invalid squares")
        piece = self.at(src)
        if piece is None:
            raise ValueError("no piece there")
        if piece.colour is not turn:
            raise ValueError("not your piece")
        target = self.at(dst)
        if target is not None and target.colour is piece.colour:
            raise ValueError("cannot capture your own piece")
        if not piece.can_move(src, dst, self):
            raise ValueError(f"{piece.symbol()} cannot move like that")

        captured = self._grid.pop((dst.row, dst.col), None)
        self._grid[(dst.row, dst.col)] = self._grid.pop((src.row, src.col))
        piece.has_moved = True
        # A real engine would now verify the mover's king is not in check and undo if so.
        return "capture" if captured else "move"


board = Board()
board.place(Rook(Colour.WHITE), Square(7, 0))
board.place(Knight(Colour.WHITE), Square(7, 1))
board.place(Pawn(Colour.BLACK), Square(4, 0))

assert board.move(Square(7, 1), Square(5, 2), Colour.WHITE) == "move"     # knight L-shape
try:
    board.move(Square(7, 0), Square(6, 2), Colour.WHITE)                  # rook, not straight
    raise AssertionError("illegal rook move allowed")
except ValueError as e:
    print("rejected:", e)

assert board.move(Square(7, 0), Square(4, 0), Colour.WHITE) == "capture"  # rook takes pawn
try:
    board.move(Square(4, 0), Square(3, 1), Colour.WHITE)                  # rooks don't go diagonally
    raise AssertionError("illegal diagonal rook move allowed")
except ValueError:
    pass
print("rook now at (4,0):", board.at(Square(4, 0)).symbol())
```

**The special rules, and where each one belongs** — say this rather than trying to implement them:

| Rule | Where it lives | Why not on the piece |
|---|---|---|
| **Castling** | Board/game level | Involves two pieces, their move history, and the squares crossed being unattacked |
| **En passant** | Game level | Depends on the *previous* move, which a piece cannot see |
| **Promotion** | Game level, after the move | Replaces a piece — a board mutation, not a movement |
| **Check / checkmate** | Board level | "Would this move leave my king attacked?" is a whole-board query |
| **Stalemate, 50-move, repetition** | Game level | Needs game history, not board state |

The general principle to state: **a piece knows its geometry; the board knows the position; the game knows the history.** Rules that need history (en passant, repetition, castling rights) cannot live on the piece, and putting them there is the most common structural mistake in this problem.

**Check detection** is worth one sentence of algorithm: after applying a move on a copy (or applying and undoing), ask whether any enemy piece `can_move` to the king's square. Checkmate is "in check and no legal move exists"; stalemate is "not in check and no legal move exists" — the same generator, different check status.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-16-chess-q1", "type": "mcq",
      "prompt": "Why can en passant not be implemented inside `Pawn.can_move`?",
      "options": [
        {"id":"a","text":"Because pawns cannot capture diagonally"},
        {"id":"b","text":"Because its legality depends on the opponent's immediately preceding move — information the piece cannot see; rules requiring game history belong at the game level, while the piece owns only its geometry"},
        {"id":"c","text":"Because it involves two pieces of the same colour"},
        {"id":"d","text":"Because it changes the board size"}
      ],
      "correct": "b",
      "explanation": "The layering rule for this problem: piece = geometry, board = current position, game = history. En passant, castling rights, threefold repetition, and the 50-move rule are all history-dependent and therefore game-level." }
] }
```

## Turn management, players, and extensions

Common to all three games, and a good closing section in any game interview:

**Turn management** is a rotating index over the player list, plus rules for extra turns (rolling a six) and skipped turns (three sixes, a forfeit). Keeping it in one `next_turn()` method rather than scattered `+= 1` statements is what stops off-by-one bugs when those rules arrive.

**Players and bots**: `Player` should hold a `MoveStrategy` — `HumanInput`, `RandomBot`, `MinimaxBot`. The game loop then never branches on "is this a bot?", and adding an AI is a new strategy class. This is the same Strategy usage as pricing in the parking lot, applied to decisions instead of money.

**Undo** is the **Command** pattern: each move is an object that can apply and reverse itself, and the game holds a stack. For chess, the reverse must restore the captured piece, the `has_moved` flags, and the en-passant square — which is exactly why a `Move` object storing that context beats trying to recompute it.

**Persistence and replay**: store the move list, not the board. The board is derivable by replaying moves from the initial position, which gives you free undo, replay, and analysis — the event-sourcing argument from the HLD lessons, in miniature.

**Multiplayer over a network** turns this into an HLD problem: a server authoritative on state, moves validated server-side (never trust the client), and the board pushed over WebSocket to spectators.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-16-turns-q1", "type": "mcq",
      "prompt": "How should a game support both human players and AI bots without branching in the game loop?",
      "options": [
        {"id":"a","text":"Subclass Game into HumanGame and BotGame"},
        {"id":"b","text":"Give each Player a `MoveStrategy` (human input, random bot, minimax bot); the loop always calls `player.strategy.choose_move(state)`, so adding an AI is a new strategy class with no change to the loop"},
        {"id":"c","text":"Check `player.is_bot` before each move"},
        {"id":"d","text":"Run bots in a separate process"}
      ],
      "correct": "b",
      "explanation": "Move selection is the varying behaviour, so it belongs behind an interface on the player. The `is_bot` flag is the Open/Closed violation, and subclassing the whole game duplicates everything to vary one decision." }
] }
```

## Key takeaways

- **The board-game skeleton is reusable**: Game (turns, status) → Board (geometry, cells) → Player (identity + move strategy) → Move (value object) → Rules (validation + termination).
- **Tic-Tac-Toe is an algorithm question in disguise.** Running counters give O(1) win detection; the diagonal `if`/`if` and the move-count draw check are the details that get probed.
- **Snake & Ladder is an edge-case question.** One `jumps` map, an explicit overshoot rule, exact landing, extra turn on six, and board validation at construction.
- **Chess is a layering question.** Piece = geometry, board = position, game = history — and every special rule sorts cleanly into one of those three.
- **Move selection is a Strategy; moves are Commands.** That pair gives you bots, undo, replay, and persistence from the same model, and it is the strongest thing you can add when the interviewer asks "how would you extend this?".
