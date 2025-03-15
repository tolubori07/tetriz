const std = @import("std");
const math = std.math;
const time = std.time;
const rl = @import("raylib");

const SQUARE_SIZE = 20;
const GRID_HORIZONTAL_SIZE = 12;
const GRID_VERTICAL_SIZE = 20;
const LATERAL_SPEED = 10;
const TURNING_SPEED = 12;
const FAST_FALL_AWAIT_COUNTER = 30;
const FADING_TIME = 33;
const color = rl.Color;
const isKeyPressed = rl.isKeyPressed;
const IsKeyDown = rl.isKeyDown;
const drawLine = rl.drawLine;
const drawText = rl.drawText;
const drawRectangle = rl.drawRectangle;

// Enums and type definitions
const GridSquare = enum {
    empty,
    moving,
    full,
    block,
    fading,
};

// Global variable definitions
const screenWidth: i32 = 800;
const screenHeight: i32 = 450;

var gameOver: bool = false;
var pause: bool = false;

// Matrices
var grid: [GRID_HORIZONTAL_SIZE][GRID_VERTICAL_SIZE]GridSquare = undefined;
var piece: [4][4]GridSquare = undefined;
var incomingPiece: [4][4]GridSquare = undefined;

// Track active piece position
var piecePositionX: usize = 0;
var piecePositionY: usize = 0;

// Game params
var fadingColor: rl.Color = undefined;

var beginPlay: bool = true;
var pieceActive: bool = false;
var detection: bool = false;
var lineToDelete: bool = false;

var level: i32 = 1;
var lines: i32 = 0;

// Counters
var gravityMovementCounter: i32 = 0;
var lateralMovementCounter: i32 = 0;
var turnMovementCounter: i32 = 0;
var fastFallMovementCounter: i32 = 0;
var fadeLineCounter: i32 = 0;

// Based on level
var gravitySpeed: i32 = 30;

//------------------------------------------------------------------------------------
// Module Functions Declaration (local)
//--------------------------------------------------------------------

// Additional module functions
fn deleteCompleteLines() i32 {
    var deletedLines: i32 = 0;

    // Erase the completed line
    var j: usize = GRID_VERTICAL_SIZE - 2;
    while (j >= 0) : (j -= 1) {
        while (grid[1][j] == GridSquare.fading) {
            for (1..GRID_HORIZONTAL_SIZE - 1) |i| {
                grid[i][j] = GridSquare.empty;
            }

            var j2 = j - 1;
            while (j2 >= 0) : (j2 -= 1) {
                var k: usize = 1;
                while (k < GRID_HORIZONTAL_SIZE - 1) : (k += 1) {
                    if (grid[k][j2] == GridSquare.full) {
                        grid[k][j2 + 1] = GridSquare.full;
                        grid[k][j2] = GridSquare.empty;
                    } else if (grid[k][j2] == GridSquare.fading) {
                        grid[k][j2 + 1] = GridSquare.fading;
                        grid[k][j2] = GridSquare.empty;
                    }
                }
            }

            deletedLines += 1;
        }
    }

    return deletedLines;
}

pub fn main() !void {
    rl.initWindow(screenWidth, screenHeight, "Classic Game: Tetris");
    try initGame();
    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        try updateDrawFrame();
    }

    rl.closeWindow();
}

fn initGame() !void {
    level = 1;
    lines = 0;
    fadingColor = color.gray;
    piecePositionX = 0;
    piecePositionY = 0;
    pause = false;
    beginPlay = true;
    pieceActive = false;
    detection = false;
    lineToDelete = false;

    gravityMovementCounter = 0;
    lateralMovementCounter = 0;
    turnMovementCounter = 0;
    fastFallMovementCounter = 0;

    fadeLineCounter = 0;
    gravitySpeed = 30;

    // Initialize the grid
    for (0..GRID_HORIZONTAL_SIZE) |i| {
        for (0..GRID_VERTICAL_SIZE) |j| {
            if ((j == GRID_VERTICAL_SIZE - 1) or (i == 0) or (i == GRID_HORIZONTAL_SIZE - 1)) {
                grid[i][j] = GridSquare.block;
            } else {
                grid[i][j] = GridSquare.empty;
            }
        }
    }

    // Initialize the incoming piece
    for (0..4) |i| {
        for (0..4) |j| {
            incomingPiece[i][j] = GridSquare.empty;
        }
    }
}

fn updateGame() !void {
    if (!gameOver) {
        if (rl.isKeyPressed(.p)) pause = !pause;
        if (!pause) {
            if (!lineToDelete) {
                if (!pieceActive) {
                    pieceActive = CreatePiece();
                    fastFallMovementCounter = 0;
                } else {
                    fastFallMovementCounter += 1;
                    gravityMovementCounter += 1;
                    lateralMovementCounter += 1;
                    turnMovementCounter += 1;

                    if (rl.isKeyPressed(.left) or rl.isKeyPressed(.right)) lateralMovementCounter = LATERAL_SPEED;
                    if (rl.isKeyPressed(.up)) turnMovementCounter = TURNING_SPEED;

                    if (rl.isKeyDown(.down) and (fastFallMovementCounter >= FAST_FALL_AWAIT_COUNTER)) {
                        gravityMovementCounter += gravitySpeed;
                    }

                    if (gravityMovementCounter >= gravitySpeed) {
                        CheckDetection(&detection);
                        resolveFallingMovement(&detection, &pieceActive);
                        CheckCompletion(&lineToDelete);
                        gravityMovementCounter = 0;
                    }

                    if (lateralMovementCounter >= LATERAL_SPEED) {
                        if (!resolveLateralMovement()) lateralMovementCounter = 0;
                    }

                    if (turnMovementCounter >= TURNING_SPEED) {
                        if (resolveTurnMovement()) turnMovementCounter = 0;
                    }
                }
                for (0..2) |j| {
                    for (1..GRID_HORIZONTAL_SIZE) |i| {
                        if (grid[i][j] == GridSquare.full) {
                            gameOver = true;
                        }
                    }
                }
            } else {
                fadeLineCounter += 1;
                if (@mod(fadeLineCounter, 8) < 4) fadingColor = color.maroon else fadingColor = color.gray;
                if (fadeLineCounter >= FADING_TIME) {
                    const deletedLines: i32 = deleteCompleteLines();
                    fadeLineCounter = 0;
                    lineToDelete = false;
                    lines += deletedLines;
                }
            }
        }
    } else {
        if (isKeyPressed(.enter)) {
            try initGame();
            gameOver = false;
        }
    }
}

fn drawGame() !void {
    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(color.ray_white);
    if (!gameOver) {
        var offset: rl.Vector2 = undefined;
        offset.x = @as(i32, screenWidth) / 2 - @as(i32, (GRID_HORIZONTAL_SIZE * SQUARE_SIZE / 2)) - 50;
        offset.y = @as(i32, screenHeight) / 2 - @as(i32, ((GRID_VERTICAL_SIZE - 1) * SQUARE_SIZE / 2)) + SQUARE_SIZE * 2;

        offset.y -= 50; // NOTE: Hardcoded position!
        const controller = offset.x;
        for (0..GRID_VERTICAL_SIZE) |j| {
            for (0..GRID_HORIZONTAL_SIZE) |i| {
                if (grid[i][j] == GridSquare.empty) {
                    drawLine(@as(i32, @intCast(offset.x)), @as(i32, @intCast(offset.y)), @as(i32, @intCast(offset.x + SQUARE_SIZE)), @as(i32, @intCast(offset.y)), color.light_gray);
                    drawLine(offset.x, offset.y, offset.x, offset.y + SQUARE_SIZE, color.light_gray);
                    drawLine(offset.x + SQUARE_SIZE, offset.y, offset.x + SQUARE_SIZE, offset.y + SQUARE_SIZE, color.light_gray);
                    drawLine(offset.x, offset.y + SQUARE_SIZE, offset.x + SQUARE_SIZE, offset.y + SQUARE_SIZE, color.light_gray);
                    offset.x += SQUARE_SIZE;
                } else if (grid[i][j] == GridSquare.full) {
                    drawRectangle(offset.x, offset.y, SQUARE_SIZE, SQUARE_SIZE, color.gray);
                    offset.x += SQUARE_SIZE;
                } else if (grid[i][j] == GridSquare.moving) {
                    drawRectangle(offset.x, offset.y, SQUARE_SIZE, SQUARE_SIZE, color.dark_gray);
                    offset.x += SQUARE_SIZE;
                } else if (grid[i][j] == GridSquare.block) {
                    drawRectangle(offset.x, offset.y, SQUARE_SIZE, SQUARE_SIZE, color.light_gray);
                    offset.x += SQUARE_SIZE;
                } else if (grid[i][j] == GridSquare.fading) {
                    drawRectangle(offset.x, offset.y, SQUARE_SIZE, SQUARE_SIZE, fadingColor);
                    offset.x += SQUARE_SIZE;
                }
            }
            offset.x = controller;
            offset.y += SQUARE_SIZE;
        }
        offset.x = 500;
        offset.y = 45;
        const controler = offset.x;
        for (0..4) |j| {
            for (0..4) |i| {
                if (incomingPiece[i][j] == GridSquare.empty) {
                    drawLine(@intCast(offset.x), @intCast(offset.y), @intCast(offset.x + SQUARE_SIZE), @intCast(offset.y), color.light_gray);
                    offset.x += SQUARE_SIZE;
                } else if (incomingPiece[i][j] == GridSquare.moving) {
                    drawRectangle(offset.x, offset.y, SQUARE_SIZE, SQUARE_SIZE, color.light_gray);
                    offset.x += SQUARE_SIZE;
                }
            }

            offset.x = controler;
            offset.y += SQUARE_SIZE;
        }

        drawText("INCOMING:", offset.x, offset.y - 100, 10, color.light_gray);
        drawText(rl.textFormat("LINES:  Di", lines), offset.x, offset.y + 20, 10, color.gray);

        if (pause) drawText("GAME PAUSED", screenWidth / 2 - rl.measureText("GAME PAUSED", 40) / 2, screenHeight / 2 - 40, 40, color.light_gray);
    } else {
        drawText("PRESS [ENTER] TO PLAY AGAIN", rl.getScreenWidth() / 2 - rl.measureText("PRESS [ENTER] TO PLAY AGAIN", 20) / 2, rl.getScreenHeight() / 2 - 50, 20, color.gray);
    }
}

fn updateDrawFrame() !void {
    try updateGame();
    try drawGame();
}

fn CreatePiece() bool {
    piecePositionX = ((GRID_HORIZONTAL_SIZE - 4) / 2);
    piecePositionY = 0;

    // If the game is starting and you are going to create the first piece, we create an extra one
    if (beginPlay) {
        try GetRandomPiece();
        beginPlay = false;
    }

    // We assign the incoming piece to the actual piece
    for (0..4) |i| {
        for (0..4) |j| {
            piece[i][j] = incomingPiece[i][j];
        }
    }

    // We assign a random piece to the incoming one
    try GetRandomPiece();

    // Assign the piece to the grid
    for (piecePositionX..piecePositionX + 4) |i| {
        for (0..4) |j| {
            if (piece[i - @as(usize, piecePositionX)][j] == GridSquare.moving) {
                grid[i][j] = GridSquare.moving;
            }
        }
    }

    return true;
}

fn GetRandomPiece() !void {
    const random = rl.getRandomValue(0, 6);

    for (0..4) |i| {
        for (0..4) |j| {
            incomingPiece[i][j] = GridSquare.empty;
        }
    }

    switch (random) {
        0 => {
            incomingPiece[1][1] = GridSquare.moving;
            incomingPiece[2][1] = GridSquare.moving;
            incomingPiece[1][2] = GridSquare.moving;
            incomingPiece[2][2] = GridSquare.moving;
        }, // Cube
        1 => {
            incomingPiece[1][0] = GridSquare.moving;
            incomingPiece[1][1] = GridSquare.moving;
            incomingPiece[1][2] = GridSquare.moving;
            incomingPiece[2][2] = GridSquare.moving;
        }, // L
        2 => {
            incomingPiece[1][2] = GridSquare.moving;
            incomingPiece[2][0] = GridSquare.moving;
            incomingPiece[2][1] = GridSquare.moving;
            incomingPiece[2][2] = GridSquare.moving;
        }, // Inverted L
        3 => {
            incomingPiece[0][1] = GridSquare.moving;
            incomingPiece[1][1] = GridSquare.moving;
            incomingPiece[2][1] = GridSquare.moving;
            incomingPiece[3][1] = GridSquare.moving;
        }, // Straight line
        4 => {
            incomingPiece[1][0] = GridSquare.moving;
            incomingPiece[1][1] = GridSquare.moving;
            incomingPiece[1][2] = GridSquare.moving;
            incomingPiece[2][1] = GridSquare.moving;
        }, // T shape
        5 => {
            incomingPiece[1][1] = GridSquare.moving;
            incomingPiece[2][1] = GridSquare.moving;
            incomingPiece[2][2] = GridSquare.moving;
            incomingPiece[3][2] = GridSquare.moving;
        }, // S shape
        6 => {
            incomingPiece[1][2] = GridSquare.moving;
            incomingPiece[2][2] = GridSquare.moving;
            incomingPiece[2][1] = GridSquare.moving;
            incomingPiece[3][1] = GridSquare.moving;
        }, // Inverted S shape
        else => {
            std.debug.print("Found unknown piece value", .{});
        },
    }
}

fn resolveFallingMovement(detect: *bool, active: *bool) void {
    // If we finished moving this piece, we stop it
    if (detect.*) {
        var j: usize = GRID_VERTICAL_SIZE - 2;
        while (j >= 0) : (j -= 1) {
            var i: usize = 1;
            while (i < GRID_HORIZONTAL_SIZE - 1) : (i += 1) {
                if (grid[i][j] == GridSquare.moving) {
                    grid[i][j] = GridSquare.full;
                    detect.* = false;
                    active.* = false;
                }
            }
        }
    } else {
        // We move down the piece
        var j: usize = GRID_VERTICAL_SIZE - 2;
        while (j >= 0) : (j -= 1) {
            var i: usize = 1;
            while (i < GRID_HORIZONTAL_SIZE - 1) : (i += 1) {
                if (grid[i][j] == GridSquare.moving) {
                    grid[i][j + 1] = GridSquare.moving;
                    grid[i][j] = GridSquare.empty;
                }
            }
        }

        piecePositionY += 1;
    }
}

fn resolveLateralMovement() bool {
    var collision: bool = false;

    // Piece movement
    if (rl.isKeyDown(.left)) // Move left
    {
        // Check if is possible to move to left
        var j: usize = GRID_VERTICAL_SIZE - 2;
        while (j >= 0) : (j -= 1) {
            var i: usize = 1;
            while (i < GRID_HORIZONTAL_SIZE - 1) : (i += 1) {
                if (grid[i][j] == GridSquare.moving) {
                    // Check if we are touching the left wall or we have a full square at the left
                    if ((i - 1 == 0) or (grid[i - 1][j] == GridSquare.full)) collision = true;
                }
            }
        }

        // If able, move left
        if (!collision) {
            var k = GRID_VERTICAL_SIZE - 2;
            while (k >= 0) : (k -= 1) {
                var i = 1;
                while (i < GRID_HORIZONTAL_SIZE - 1) : (i += 1) { // Move everything to the left
                    if (grid[i][k] == GridSquare.moving) {
                        grid[i - 1][k] = GridSquare.moving;
                        grid[i][k] = GridSquare.empty;
                    }
                }
            }

            piecePositionX -= 1;
        }
    } else if (rl.isKeyDown(.right)) // Move right
    {
        // Check if is possible to move to right
        var j: usize = GRID_VERTICAL_SIZE - 2;
        while (j >= 0) : (j -= 1) {
            var i: usize = 1;
            while (i < GRID_HORIZONTAL_SIZE - 1) : (i += 1) {
                if (grid[i][j] == GridSquare.moving) {
                    // Check if we are touching the right wall or we have a full square at the right
                    if ((i + 1 == GRID_HORIZONTAL_SIZE - 1) or (grid[i + 1][j] == GridSquare.full)) {
                        collision = true;
                    }
                }
            }
        }

        // If able move right
        if (!collision) {
            var l = GRID_VERTICAL_SIZE - 2;
            while (l >= 0) : (l -= 1) {
                var i = 1;
                while (i < GRID_HORIZONTAL_SIZE - 1) : (i += 1) { // Move everything to the right
                    if (grid[i][l] == GridSquare.moving) {
                        grid[i + 1][l] = GridSquare.moving;
                        grid[i][l] = GridSquare.empty;
                    }
                }
            }

            piecePositionX += 1;
        }
    }

    return collision;
}

fn resolveTurnMovement() bool {
    // Input for turning the piece
    if (IsKeyDown(.up)) {
        var aux: GridSquare = undefined;
        var checker: bool = false;

        // Check all turning possibilities
        if ((grid[piecePositionX + 3][piecePositionY] == GridSquare.moving) and
            (grid[piecePositionX][piecePositionY] != GridSquare.empty) and
            (grid[piecePositionX][piecePositionY] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 3][piecePositionY + 3] == GridSquare.moving) and
            (grid[piecePositionX + 3][piecePositionY] != GridSquare.empty) and
            (grid[piecePositionX + 3][piecePositionY] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX][piecePositionY + 3] == GridSquare.moving) and
            (grid[piecePositionX + 3][piecePositionY + 3] != GridSquare.empty) and
            (grid[piecePositionX + 3][piecePositionY + 3] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX][piecePositionY] == GridSquare.moving) and
            (grid[piecePositionX][piecePositionY + 3] != GridSquare.empty) and
            (grid[piecePositionX][piecePositionY + 3] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 1][piecePositionY] == GridSquare.moving) and
            (grid[piecePositionX][piecePositionY + 2] != GridSquare.empty) and
            (grid[piecePositionX][piecePositionY + 2] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 3][piecePositionY + 1] == GridSquare.moving) and
            (grid[piecePositionX + 1][piecePositionY] != GridSquare.empty) and
            (grid[piecePositionX + 1][piecePositionY] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 2][piecePositionY + 3] == GridSquare.moving) and
            (grid[piecePositionX + 3][piecePositionY + 1] != GridSquare.empty) and
            (grid[piecePositionX + 3][piecePositionY + 1] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX][piecePositionY + 2] == GridSquare.moving) and
            (grid[piecePositionX + 2][piecePositionY + 3] != GridSquare.empty) and
            (grid[piecePositionX + 2][piecePositionY + 3] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 2][piecePositionY] == GridSquare.moving) and
            (grid[piecePositionX][piecePositionY + 1] != GridSquare.empty) and
            (grid[piecePositionX][piecePositionY + 1] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 3][piecePositionY + 2] == GridSquare.moving) and
            (grid[piecePositionX + 2][piecePositionY] != GridSquare.empty) and
            (grid[piecePositionX + 2][piecePositionY] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 1][piecePositionY + 3] == GridSquare.moving) and
            (grid[piecePositionX + 3][piecePositionY + 2] != GridSquare.empty) and
            (grid[piecePositionX + 3][piecePositionY + 2] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX][piecePositionY + 1] == GridSquare.moving) and
            (grid[piecePositionX + 1][piecePositionY + 3] != GridSquare.empty) and
            (grid[piecePositionX + 1][piecePositionY + 3] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 1][piecePositionY + 1] == GridSquare.moving) and
            (grid[piecePositionX + 1][piecePositionY + 2] != GridSquare.empty) and
            (grid[piecePositionX + 1][piecePositionY + 2] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 2][piecePositionY + 1] == GridSquare.moving) and
            (grid[piecePositionX + 1][piecePositionY + 1] != GridSquare.empty) and
            (grid[piecePositionX + 1][piecePositionY + 1] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 2][piecePositionY + 2] == GridSquare.moving) and
            (grid[piecePositionX + 2][piecePositionY + 1] != GridSquare.empty) and
            (grid[piecePositionX + 2][piecePositionY + 1] != GridSquare.moving)) checker = true;

        if ((grid[piecePositionX + 1][piecePositionY + 2] == GridSquare.moving) and
            (grid[piecePositionX + 2][piecePositionY + 2] != GridSquare.empty) and
            (grid[piecePositionX + 2][piecePositionY + 2] != GridSquare.moving)) checker = true;

        if (!checker) {
            // Rotate the piece
            aux = piece[0][0];
            piece[0][0] = piece[3][0];
            piece[3][0] = piece[3][3];
            piece[3][3] = piece[0][3];
            piece[0][3] = aux;

            aux = piece[1][0];
            piece[1][0] = piece[3][1];
            piece[3][1] = piece[2][3];
            piece[2][3] = piece[0][2];
            piece[0][2] = aux;

            aux = piece[2][0];
            piece[2][0] = piece[3][2];
            piece[3][2] = piece[1][3];
            piece[1][3] = piece[0][1];
            piece[0][1] = aux;

            aux = piece[1][1];
            piece[1][1] = piece[2][1];
            piece[2][1] = piece[2][2];
            piece[2][2] = piece[1][2];
            piece[1][2] = aux;
        }

        // Clear the current piece from the grid
        var j: usize = GRID_VERTICAL_SIZE - 2;
        while (j >= 0) : (j -= 1) {
            var i: usize = 1;
            while (i < GRID_HORIZONTAL_SIZE - 1) : (i += 1) {
                if (grid[i][j] == GridSquare.moving) {
                    grid[i][j] = GridSquare.empty;
                }
            }
        }

        // Place the rotated piece on the grid
        for (piecePositionX..piecePositionX + 4) |i| {
            for (piecePositionY..piecePositionY + 4) |k| {
                if (piece[i - piecePositionX][k - piecePositionY] == GridSquare.moving) {
                    grid[i][k] = GridSquare.moving;
                }
            }
        }
        return true;
    }
    return false;
}

fn CheckDetection(detect: *bool) void {
    var j: usize = GRID_VERTICAL_SIZE - 2;
    while (j >= 0) : (j -= 1) {
        for (1..GRID_HORIZONTAL_SIZE - 1) |i| {
            if ((grid[i][j] == GridSquare.moving) and ((grid[i][j + 1] == GridSquare.full) or (grid[i][j + 1] == GridSquare.block))) {
                detect.* = true;
            }
        }
    }
}

fn CheckCompletion(toDelete: *bool) void {
    var calculator: i32 = 0;
    var j: usize = GRID_VERTICAL_SIZE - 2;
    while (j >= 0) : (j -= 1) {
        calculator = 0;
        for (0..GRID_HORIZONTAL_SIZE - 1) |i| {
            // Count each square of the line
            if (grid[i][j] == GridSquare.full) {
                calculator += 1;
            }

            // Check if we completed the whole line
            if (calculator == GRID_HORIZONTAL_SIZE - 2) {
                toDelete.* = true;
                calculator = 0;

                // Mark the completed line
                for (1..GRID_HORIZONTAL_SIZE - 1) |z| {
                    grid[z][j] = GridSquare.fading;
                }
            }
        }
    }
}
