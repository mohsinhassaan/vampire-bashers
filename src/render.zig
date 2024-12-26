const std = @import("std");
const builtin = @import("builtin");
const sprites = @import("sprites.zig");

pub const BACKGROUND_CHAR = ' ';
pub const DEFAULT_FOREGROUND = Color{ .r = 255, .g = 255, .b = 255 };
pub const DEFAULT_BACKGROUND = Color{ .r = 0, .g = 0, .b = 0 };

pub fn Renderer(WriterType: type) type {
    return struct {
        writer: WriterType,

        const Self = @This();

        pub fn drawFrame(self: Self, frame: Frame) !void {
            try self.drawBackground(frame.term_size);
            for (frame.draw_list) |drawing| {
                try self.draw(drawing);
            }
        }

        pub fn draw(self: Self, drawing: Drawing) !void {
            try self.moveCursor(drawing.position);

            var line_start = drawing.position;
            const sprite = sprites.enumToSprite(drawing.sprite);
            for (sprite.texture, 0..) |pixel, i| {
                if (i % sprite.cols == 0) {
                    line_start.y += 1;
                    try self.moveCursor(line_start);
                }

                try self.setForeground(pixel.foreground);
                try self.setBackground(pixel.background);

                if (pixel.char) |c| {
                    _ = try self.writer.writeByte(c);
                } else {
                    try self.moveCursorForwards(1);
                }
            }
        }

        fn drawBackground(self: Self, term_size: TermSize) !void {
            try self.setForeground(DEFAULT_FOREGROUND);
            try self.setBackground(DEFAULT_BACKGROUND);
            for (0..term_size.height + 1) |y| {
                try self.moveCursor(.{
                    .x = 0,
                    .y = @intCast(y),
                });
                try self.writer.writeByteNTimes(BACKGROUND_CHAR, term_size.width);
            }
        }

        fn setForeground(self: Self, color: Color) !void {
            try self.writer.print("\x1b[38;2;{};{};{}m", .{ color.r, color.g, color.b });
        }

        fn setBackground(self: Self, color: Color) !void {
            try self.writer.print("\x1b[48;2;{};{};{}m", .{ color.r, color.g, color.b });
        }

        fn moveCursor(self: Self, pos: Position) !void {
            try self.writer.print("\x1b[{};{}H", .{ pos.y, pos.x });
        }

        fn moveCursorUp(self: Self, count: ?u16) !void {
            try self.writer.print("\x1b[{}A", .{count orelse 1});
        }

        fn moveCursorDown(self: Self, count: ?u16) !void {
            try self.writer.print("\x1b[{}B", .{count orelse 1});
        }

        fn moveCursorForwards(self: Self, count: ?u16) !void {
            try self.writer.print("\x1b[{}C", .{count orelse 1});
        }

        pub fn moveCursorBackwards(self: Self, count: ?u16) !void {
            try self.writer.print("\x1b[{}D", .{count orelse 1});
        }

        pub fn clear(self: Self) !void {
            _ = try self.writer.write("\x1b[2J");
        }
    };
}

pub fn initRenderer(writer: anytype) !Renderer(@TypeOf(writer)) {
    _ = try writer.write("\x1b[?25l");
    return .{ .writer = writer };
}

pub const Position = struct { x: u16, y: u16 };

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Pixel = struct {
    char: ?u8,
    foreground: Color = DEFAULT_FOREGROUND,
    background: Color = DEFAULT_BACKGROUND,
};

pub const Drawing = struct {
    sprite: sprites.SpriteEnum,
    position: Position,
};

pub const Frame = struct {
    term_size: TermSize,
    draw_list: []const Drawing,
};

pub const TermSize = struct {
    width: u16,
    height: u16,
};

pub fn termSize(file: std.fs.File) !?TermSize {
    if (!file.supportsAnsiEscapeCodes()) {
        return null;
    }
    return switch (builtin.os.tag) {
        .windows => blk: {
            var buf: std.os.windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            break :blk switch (std.os.windows.kernel32.GetConsoleScreenBufferInfo(
                file.handle,
                &buf,
            )) {
                std.os.windows.TRUE => TermSize{
                    .width = @intCast(buf.srWindow.Right - buf.srWindow.Left + 1),
                    .height = @intCast(buf.srWindow.Bottom - buf.srWindow.Top + 1),
                },
                else => error.Unexpected,
            };
        },
        .linux, .macos => blk: {
            var buf: std.posix.system.winsize = undefined;
            break :blk switch (std.posix.errno(
                std.posix.system.ioctl(
                    file.handle,
                    std.posix.T.IOCGWINSZ,
                    @intFromPtr(&buf),
                ),
            )) {
                .SUCCESS => TermSize{
                    .width = buf.ws_col,
                    .height = buf.ws_row,
                },
                else => error.IoctlError,
            };
        },
        else => error.Unsupported,
    };
}
