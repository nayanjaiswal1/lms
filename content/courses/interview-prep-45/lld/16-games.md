---
kind: lesson
id_key: interview-prep-45/lld-16-games
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Design Games — Tic-Tac-Toe, Snake and Ladder, Chess"
position: 16
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

Games get asked because they pack a lot of design into a small space: a board, players, turns, rules, and a way to decide who's won. These three, taken in increasing order of difficulty, cover the whole range — Tic-Tac-Toe checks whether you can spot the O(1) win check, Snake & Ladder checks whether you can model turns and edge cases cleanly, and Chess checks whether you can build a truly extensible, polymorphic set of rules.

Here's the shared skeleton behind every board game, worth stating before writing a single class:

```
Game        owns the board, the turn order, whose turn it is, and the overall status
Board       owns the cells and the geometry (is this position even valid?)
Player      an identity, plus a strategy for choosing a move (human or bot)
Move        a value object: what was actually attempted
Rules       validate a move, and detect when the game is over
GameStatus  IN_PROGRESS | WON | DRAW | ABANDONED
```

## Tic-Tac-Toe — the O(1) win check

**The real design point here isn't the classes — it's how you detect a win.** Re-scanning the whole board after every single move is O(n²). Instead, keep a running total per row, per column, and for both diagonals: player 1 adds +1, player 2 adds −1, and the moment any single counter reaches ±n, that's a win. Every move only ever touches one row, one column, and possibly both diagonals — so the check is O(1).

```python
class TicTacToe:
    """O(1) per move: running counters, instead of rescanning the whole board."""

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
        if row + col == self.n - 1:          # NOT elif: the centre of an odd board is on both
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
assert game.move(0, 2, 1) == "player 1 wins"          # the top row is complete

try:
    game.move(0, 0, 2)
    raise AssertionError("re-using a cell was allowed")
except ValueError as e:
    print("rejected:", e)

# X O X
# X O O   -- no line is ever complete, so a full board is a draw
# O X X
draw = TicTacToe(3)
for r, c, p in [(0,0,1),(0,1,2),(0,2,1),(1,1,2),(1,0,1),(1,2,2),(2,1,1),(2,0,2),(2,2,1)]:
    result = draw.move(r, c, p)
assert result == "draw"
print("full board result:", result)
```

Two details that come up whenever this problem is probed further: the diagonal updates use two separate `if` statements, **not** `if`/`elif`, because on an odd-sized board the exact centre cell sits on both diagonals at once. And a draw gets detected by simply counting moves, never by scanning the board for empty cells.

> **Remember:** the centre cell of an odd-sized board sits on both diagonals. Use two separate `if`s, not `if`/`elif`, or you'll miss a real win.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-16-ttt-q1", "type": "mcq",
      "prompt": "Why do the two diagonal counter updates use separate `if` statements instead of `if`/`elif`?",
      "options": [
        {"id":"a","text":"Because `elif` runs more slowly"},
        {"id":"b","text":"On an odd-sized board, the exact centre cell satisfies both `row == col` and `row + col == n-1` at once, so it sits on both diagonals and needs to update both counters"},
        {"id":"c","text":"Because the anti-diagonal counter always has to be updated regardless"},
        {"id":"d","text":"Because the board might not be square"}
      ],
      "correct": "b",
      "explanation": "For n=3, the centre cell (1,1) sits on both diagonals at once. `elif` would skip updating the anti-diagonal there, which would make a diagonal win running through the centre completely undetectable." }
] }
```

## Snake & Ladder — clean turn and state modelling

There's no clever algorithm hiding here. This problem gets asked purely to see whether you model **turns, rules, and how the game ends** cleanly, and whether you actually handle the edge cases.

| Rule question | Typical answer | Where it lives |
|---|---|---|
| What if a roll overshoots the final square? | Stay put (or bounce back) — this is a deliberate rule, not an accident | `MovementRule` |
| What happens on rolling a six? | Roll again | The turn loop |
| Three sixes in a row? | The turn is forfeited | The turn loop |
| Do you need to land exactly on square 100? | Yes | `MovementRule` |
| Can a snake's head also be a ladder's bottom? | No — check this when the board is built | A `Board` invariant |
| How many dice? | Configurable — one or two | A `Dice` strategy |

Modelling both snakes and ladders as one single `jumps: {start: end}` map is the simplification worth saying out loud: a snake is just a jump to a lower square, and a ladder a jump to a higher one, so a single lookup handles both, and checking "no square is both a start and an end" becomes trivially easy.

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
    """Deterministic dice — the same seam a real design would use for a RandomDice."""
    def __init__(self, values: list[int]): self._values, self._i = values, 0
    def roll(self) -> int:
        value = self._values[self._i % len(self._values)]
        self._i += 1
        return value


@dataclass
class Board:
    size: int
    jumps: dict[int, int] = field(default_factory=dict)   # a snake OR a ladder — same shape

    def __post_init__(self):
        for start, end in self.jumps.items():
            if not (1 <= start <= self.size and 1 <= end <= self.size):
                raise ValueError(f"jump {start}->{end} is off the board")
            if end in self.jumps:                         # this rules out chained jumps
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
                break                                   # you must land exactly on the last square
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


board = Board(size=20, jumps={3: 15, 17: 5})            # a ladder 3->15, a snake 17->5
alice, bob = Player("alice"), Player("bob")
# alice: 3 (up the ladder to 15) ... bob: 5 ... alice: 6, then 6 again -> overshoot handling
game = Game(board, [alice, bob], ScriptedDice([3, 5, 2, 4, 3, 6, 4, 1]))

assert game.play_turn() == "in progress"
assert alice.position == 15                              # took the ladder
game.play_turn(); assert bob.position == 5               # rolled a 5
game.play_turn()                                         # alice: 15 + 2 = 17, down the snake to 5
assert alice.position == 5 and game.log[-1].endswith("snake")

# Landing exactly on the final square wins.
sprint = Game(Board(size=10), [Player("a"), Player("b")], ScriptedDice([5, 1, 5]))
sprint.play_turn()                                       # a -> 5
sprint.play_turn()                                       # b -> 1
assert sprint.play_turn() == "a wins"                    # a: 5 + 5 = 10, exactly
assert sprint.status is Status.WON and sprint.winner.name == "a"

print("\n".join(game.log))
print("sprint winner:", sprint.winner.name)
```

> **Remember:** a snake and a ladder are the same mechanic — a jump to a different square. One map, one lookup, and validation becomes a single check.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-16-snl-q1", "type": "mcq",
      "prompt": "Why model snakes and ladders as one single `jumps: {start: end}` map instead of two separate collections?",
      "options": [
        {"id":"a","text":"It uses less memory overall"},
        {"id":"b","text":"They're really the same mechanic — a jump to a different square — differing only in direction, so one lookup handles both, and board validation (no square is both a jump's start and its destination) becomes a single check"},
        {"id":"c","text":"Because ladders have to be processed before snakes"},
        {"id":"d","text":"Because a player can only ever use each ladder once"}
      ],
      "correct": "b",
      "explanation": "Recognising that two named ideas actually share one mechanic is the real modelling insight here. Direction can always be worked out from the map itself (`end > start` means a ladder), so it doesn't need its own separate field." }
] }
```

## Chess — polymorphic rules and extensibility

Chess is the hard one here, and nobody expects you to build a full working game in 45 minutes. What actually gets expected is the **shape**: a piece hierarchy that's genuinely easy to extend, move validation kept separate from actually making the move, and a clear plan for handling the special rules.

**The core decision: every piece owns its own movement rule.** This is polymorphism doing exactly the job it exists for — adding a whole new piece type (a fairy-chess variant, a custom rule set) means writing one new class, and editing nothing else at all.

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum


class Colour(Enum):
    WHITE = "w"
    BLACK = "b"


@dataclass(frozen=True)
class Square:                                   # a value object
    row: int
    col: int
    def valid(self) -> bool: return 0 <= self.row < 8 and 0 <= self.col < 8


class Piece(ABC):
    def __init__(self, colour: Colour): self.colour, self.has_moved = colour, False

    @abstractmethod
    def symbol(self) -> str: ...

    @abstractmethod
    def can_move(self, src: Square, dst: Square, board: "Board") -> bool:
        """Geometry only. Whether the path is clear, and whether it's legal, is the board's job."""

    def path_clear(self, src: Square, dst: Square, board: "Board") -> bool:
        step_r = (dst.row > src.row) - (dst.row < src.row)      # a sign: -1, 0, or 1
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
    def can_move(self, src, dst, board):        # a jump — it never has to check the path
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
        if sideways == 0 and target is None:                    # a straight push
            if forward == direction:
                return True
            return (forward == 2 * direction and not self.has_moved
                    and board.at(Square(src.row + direction, src.col)) is None)
        if sideways == 1 and forward == direction:              # a diagonal capture only
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
        """The check order matters: ownership, then geometry, then the destination."""
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
        # A real engine would now check whether the mover's own king is left in check, and undo if so.
        return "capture" if captured else "move"


board = Board()
board.place(Rook(Colour.WHITE), Square(7, 0))
board.place(Knight(Colour.WHITE), Square(7, 1))
board.place(Pawn(Colour.BLACK), Square(4, 0))

assert board.move(Square(7, 1), Square(5, 2), Colour.WHITE) == "move"     # a knight's L-shape
try:
    board.move(Square(7, 0), Square(6, 2), Colour.WHITE)                  # a rook can't move diagonally
    raise AssertionError("illegal rook move allowed")
except ValueError as e:
    print("rejected:", e)

assert board.move(Square(7, 0), Square(4, 0), Colour.WHITE) == "capture"  # the rook takes the pawn
try:
    board.move(Square(4, 0), Square(3, 1), Colour.WHITE)                  # still no diagonal rook moves
    raise AssertionError("illegal diagonal rook move allowed")
except ValueError:
    pass
print("rook now at (4,0):", board.at(Square(4, 0)).symbol())
```

**The special rules, and exactly where each one belongs** — say this rather than trying to actually implement all of it:

| Rule | Where it lives | Why not directly on the piece |
|---|---|---|
| **Castling** | The board or game level | It involves two pieces, whether either has moved before, and whether the squares crossed are under attack |
| **En passant** | The game level | It depends on the *previous* move, which a piece has no way to see on its own |
| **Promotion** | The game level, right after the move | It replaces a piece entirely — that's a board mutation, not a movement |
| **Check and checkmate** | The board level | "Would this move leave my own king under attack?" is a whole-board question |
| **Stalemate, the 50-move rule, repetition** | The game level | These all need the game's history, not just the current board state |

The general rule worth stating: **a piece knows only its own geometry; the board knows the current position; the game knows the full history.** Any rule that needs history — en passant, castling rights, repeated positions — simply can't live on the piece, and putting it there anyway is the single most common structural mistake in this exact problem.

**Detecting check is worth one sentence of algorithm**: after making a move on a copy of the board (or making it and then undoing it), ask whether any enemy piece's `can_move` reaches the king's square. Checkmate is "in check, with no legal move available." Stalemate is "not in check, with no legal move available" — the exact same move generator, just checked against a different condition.

> **Remember:** a piece only knows its geometry. The board knows the current position. The game knows the history. Any rule needing history belongs at the game level.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-16-chess-q1", "type": "mcq",
      "prompt": "Why can't en passant be implemented directly inside `Pawn.can_move`?",
      "options": [
        {"id":"a","text":"Because pawns can't capture diagonally at all"},
        {"id":"b","text":"Its legality depends entirely on the opponent's immediately preceding move — information the piece has no way to see. Rules that need game history belong at the game level; the piece only owns its own geometry"},
        {"id":"c","text":"Because it involves two pieces of the same colour"},
        {"id":"d","text":"Because it changes the size of the board"}
      ],
      "correct": "b",
      "explanation": "This problem's layering rule: a piece owns geometry, the board owns the current position, and the game owns history. En passant, castling rights, repeated positions, and the 50-move rule are all history-dependent, and so all of them belong at the game level." }
] }
```

## Turn management, players, and extensions

This next part applies to all three games, and it makes for a good closing section in any game-design interview.

**Turn management** is just a rotating index into the player list, plus a couple of extra rules: extra turns (rolling a six) and skipped turns (three sixes, a forfeit). Keeping all of that inside one `next_turn()` method, rather than scattering `turn += 1` statements everywhere, is exactly what stops off-by-one bugs the moment those extra rules show up.

**Players and bots**: give `Player` a `MoveStrategy` — `HumanInput`, `RandomBot`, `MinimaxBot`. The game loop never has to branch on "is this a bot?" at all, and adding an AI just means adding a new strategy class. This is the exact same use of Strategy as pricing was in the parking lot, just applied to a decision instead of to money.

**Undo** is the **Command** pattern: every move becomes an object that knows how to both apply and reverse itself, and the game just holds a stack of them. In chess specifically, reversing a move has to restore the captured piece, the `has_moved` flags, and the en-passant square — which is exactly why storing that context on a `Move` object beats trying to recompute it afterward.

**Saving and replaying a game**: store the list of moves, not the board itself. The board can always be rebuilt by replaying those moves from the starting position, which gives you undo, replay, and analysis essentially for free — this is the same event-sourcing idea from the HLD lessons, at a much smaller scale.

**Multiplayer over a network** turns this into an HLD problem: a server that's the final authority on the game state, every move validated on the server (never trust the client), with the board pushed out over a WebSocket to anyone watching.

> **Remember:** move selection is a Strategy, and moves themselves are Commands. That one pair gives you bots, undo, replay, and saving — all from the exact same model.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-16-turns-q1", "type": "mcq",
      "prompt": "How should a game support both human players and AI bots, without any branching in the game loop itself?",
      "options": [
        {"id":"a","text":"Subclass Game into HumanGame and BotGame"},
        {"id":"b","text":"Give each Player a `MoveStrategy` (human input, a random bot, a minimax bot); the loop always just calls `player.strategy.choose_move(state)`, so adding an AI is a new strategy class with zero changes to the loop"},
        {"id":"c","text":"Check `player.is_bot` before every single move"},
        {"id":"d","text":"Run every bot in a separate process"}
      ],
      "correct": "b",
      "explanation": "Move selection is the part that actually varies, so it belongs behind an interface on the player. An `is_bot` flag is exactly the Open/Closed violation this design is meant to avoid, and subclassing the whole game duplicates everything just to vary one single decision." }
] }
```

## Quick recap

- **The board-game skeleton is reusable everywhere**: Game (turns, status), Board (geometry, cells), Player (identity plus a move strategy), Move (a value object), Rules (validation plus deciding when it's over).
- **Tic-Tac-Toe is really an algorithm question wearing a game's clothes.** Running counters give you O(1) win detection; the two separate `if`s for the diagonals, and detecting a draw by move count, are exactly the details that get probed further.
- **Snake & Ladder is really an edge-case question.** One `jumps` map, an explicit overshoot rule, landing exactly, an extra turn for a six, and board validation right when it's built.
- **Chess is really a layering question.** Piece equals geometry, board equals position, game equals history — and every single special rule sorts cleanly into exactly one of those three.
- **Move selection is a Strategy; moves themselves are Commands.** That pair gives you bots, undo, replay, and saving from the same model, and it's the strongest thing you can offer when asked "how would you extend this?"
