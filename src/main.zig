const std = @import("std");
const render = @import("render.zig");
const sprites = @import("sprites.zig");

const default_termsize = render.TermSize{
    .width = 50,
    .height = 50,
};

pub fn main() !void {
    const stdout = std.io.getStdOut();
    var buf_writer = std.io.bufferedWriter(stdout.writer());
    const renderer = try render.initRenderer(buf_writer.writer());

    var i: u16 = 0;
    var term_size = try render.termSize(stdout) orelse default_termsize;
    const term_pixels = @as(usize, term_size.width) * @as(usize, term_size.height);
    var draw_list = [_]render.Drawing{
        render.Drawing{
            .sprite = sprites.SpriteEnum.enemy_medium,
            .position = .{ .x = 0, .y = 0 },
        },
    };
    while (i < term_pixels) : (i += 1) {
        // defer std.time.sleep(17 * std.time.ns_per_ms);
        defer std.time.sleep(50 * std.time.ns_per_ms);

        term_size = try render.termSize(stdout) orelse default_termsize;
        const frame = render.Frame{
            .term_size = term_size,
            .draw_list = &draw_list,
        };

        try renderer.drawFrame(frame);
        try buf_writer.flush();

        for (&draw_list) |*drawable| {
            drawable.position.x = i % term_size.width;
            drawable.position.y = i / term_size.width;
        }
    }
}

test {
    _ = render;
    _ = sprites;
    std.testing.refAllDecls(@This());
}
