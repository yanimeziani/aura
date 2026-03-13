const std = @import("std");

pub fn main() !void {
    std.debug.print("Enter a char: ", .{});
    var buf: [1]u8 = undefined;
    const len = try std.posix.read(std.posix.STDIN_FILENO, &buf);
    if (len > 0) {
        std.debug.print("You entered: {c}\n", .{buf[0]});
    }
}
