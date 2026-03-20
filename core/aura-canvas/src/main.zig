const std = @import("std");

/// A simple AR/Canvas pixel buffer renderer
pub const Canvas = struct {
    width: u32,
    height: u32,
    pixels: []u32, // ARGB or RGBA pixel buffer
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Canvas {
        const pixels = try allocator.alloc(u32, width * height);
        @memset(pixels, 0xFF000000); // Black background, fully opaque
        return Canvas{
            .width = width,
            .height = height,
            .pixels = pixels,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Canvas) void {
        self.allocator.free(self.pixels);
    }

    pub fn setPixel(self: *Canvas, x: u32, y: u32, color: u32) void {
        if (x < self.width and y < self.height) {
            self.pixels[y * self.width + x] = color;
        }
    }

    pub fn clear(self: *Canvas, color: u32) void {
        @memset(self.pixels, color);
    }

    /// Basic line drawing (Bresenham's)
    pub fn drawLine(self: *Canvas, x0: i32, y0: i32, x1: i32, y1: i32, color: u32) void {
        const dx = @abs(x1 - x0);
        const dy = -@as(i32, @intCast(@abs(y1 - y0)));
        const sx: i32 = if (x0 < x1) 1 else -1;
        const sy: i32 = if (y0 < y1) 1 else -1;
        var err = @as(i32, @intCast(dx)) + dy;
        var cx = x0;
        var cy = y0;

        while (true) {
            if (cx >= 0 and cx < self.width and cy >= 0 and cy < self.height) {
                self.setPixel(@intCast(cx), @intCast(cy), color);
            }
            if (cx == x1 and cy == y1) break;
            const e2 = 2 * err;
            if (e2 >= dy) {
                err += dy;
                cx += sx;
            }
            if (e2 <= dx) {
                err += @intCast(dx);
                cy += sy;
            }
        }
    }

    /// Simulated AR projection: draw a 3D point onto the 2D canvas
    pub fn projectPoint(self: *Canvas, x: f32, y: f32, z: f32, fov: f32, color: u32) void {
        if (z <= 0) return; // Behind camera
        const aspect = @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
        const f = 1.0 / @tan(fov / 2.0);
        
        // Simple perspective divide
        const px = (x * f) / z;
        const py = (y * f * aspect) / z;
        
        // Map to screen coordinates
        const sx = @as(i32, @intFromFloat((px + 1.0) * 0.5 * @as(f32, @floatFromInt(self.width))));
        const sy = @as(i32, @intFromFloat((py + 1.0) * 0.5 * @as(f32, @floatFromInt(self.height))));
        
        if (sx >= 0 and sx < self.width and sy >= 0 and sy < self.height) {
            self.setPixel(@intCast(sx), @intCast(sy), color);
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var canvas = try Canvas.init(allocator, 800, 600);
    defer canvas.deinit();

    // Draw a grid for AR tracking simulation
    canvas.clear(0xFF111111); // Dark grey

    // Draw horizon line
    canvas.drawLine(0, 300, 800, 300, 0xFF00FF00); // Green

    // Project some 3D points
    canvas.projectPoint(-2.0, -1.0, 5.0, std.math.pi / 2.0, 0xFFFF0000); // Red
    canvas.projectPoint( 2.0, -1.0, 5.0, std.math.pi / 2.0, 0xFF0000FF); // Blue
    canvas.projectPoint( 0.0,  2.0, 5.0, std.math.pi / 2.0, 0xFFFFFFFF); // White

    std.debug.print("Canvas initialized and AR elements projected. Buffer size: {d} pixels.\n", .{canvas.pixels.len});
}

test "canvas init and pixel set" {
    const allocator = std.testing.allocator;
    var canvas = try Canvas.init(allocator, 100, 100);
    defer canvas.deinit();

    try std.testing.expectEqual(canvas.width, 100);
    try std.testing.expectEqual(canvas.height, 100);

    canvas.setPixel(50, 50, 0xFFFFFFFF);
    try std.testing.expectEqual(canvas.pixels[50 * 100 + 50], 0xFFFFFFFF);
}
