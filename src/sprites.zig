const std = @import("std");
const render = @import("render.zig");
const sprite_file = "data/sprites.txt";
const sprite_file_data = @embedFile(sprite_file);

pub const sprite_sheet = generateSpriteSheet(sprite_file_data);

pub const Sprite = struct {
    texture: []const render.Pixel,
    cols: u16,
    z_index: u8,
};

pub const SpriteEnum = enum {
    bullet,
    enemy_small,
    enemy_medium,
    player,
};

pub const SpriteSheet = struct {
    bullet: Sprite,
    enemy_small: Sprite,
    enemy_medium: Sprite,
    player: Sprite,
};

pub fn enumToSprite(sprite_enum: SpriteEnum) Sprite {
    return switch (sprite_enum) {
        .bullet => sprite_sheet.bullet,
        .enemy_small => sprite_sheet.enemy_small,
        .enemy_medium => sprite_sheet.enemy_medium,
        .player => sprite_sheet.player,
    };
}

pub fn generateSpriteSheet(comptime sprite_data: []const u8) SpriteSheet {
    comptime var line_iter = std.mem.tokenizeScalar(u8, sprite_data, '\n');
    comptime var ss: SpriteSheet = undefined;
    const sprite_count = comptime std.fmt.parseInt(
        u32,
        line_iter.next() orelse @compileError("No lines in sprite data."),
        10,
    ) catch @compileError("Unable to parse sprite count.");

    inline for (0..sprite_count) |sprite_index| {
        const metadata = comptime line_iter.next() orelse
            @compileError(std.fmt.comptimePrint(
            "Expected {d} sprites in sprite data. Found {d}.",
            .{ sprite_count, sprite_index },
        ));
        comptime var word_iter = std.mem.tokenizeScalar(u8, metadata, ' ');
        const name = comptime word_iter.next() orelse
            @compileError(std.fmt.comptimePrint(
            "No name in sprite metadata line {?d}: '{s}'",
            .{ line_iter.index, metadata },
        ));
        const width = comptime std.fmt.parseInt(
            u16,
            word_iter.next() orelse
                @compileError(std.fmt.comptimePrint(
                "No width in sprite metadata line {?d}: '{s}'",
                .{ line_iter.index, metadata },
            )),
            10,
        ) catch @compileError("Unable to parse sprite width.");
        const height = comptime std.fmt.parseInt(
            u16,
            word_iter.next() orelse
                @compileError(std.fmt.comptimePrint(
                "No height in sprite metadata line {?d}: '{s}'",
                .{ line_iter.index, metadata },
            )),
            10,
        ) catch @compileError("Unable to parse sprite height.");
        const z_index = comptime std.fmt.parseInt(
            u16,
            word_iter.next() orelse
                @compileError(std.fmt.comptimePrint(
                "No z-index in sprite metadata line {?d}: '{s}'",
                .{ line_iter.index, metadata },
            )),
            10,
        ) catch @compileError("Unable to parse sprite z-index.");

        comptime var texture: [width * height]render.Pixel = undefined;
        comptime var i: usize = 0;

        comptime var sprite: *Sprite = &@field(ss, name);

        sprite.cols = width;
        sprite.z_index = z_index;
        inline for (0..height) |_| {
            const line = comptime line_iter.next().?;
            inline for (line) |c| {
                defer i += 1;
                if (c == '.') {
                    texture[i].char = null;
                } else {
                    texture[i].char = c;
                }
                texture[i].foreground = render.DEFAULT_FOREGROUND;
                texture[i].background = render.DEFAULT_BACKGROUND;
            }
        }

        const const_texture = comptime texture;
        sprite.texture = &const_texture;
    }

    return ss;
}

test "load default sprite sheet" {
    try std.json.stringify(enumToSprite(SpriteEnum.bullet), .{ .whitespace = .indent_2 }, std.io.getStdOut().writer());
}
