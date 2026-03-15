//! SSE (Server-Sent Events) helper — aura-api.
//! Zig 0.15.2 + std only.

const std = @import("std");

/// Write an SSE event to the writer.
pub fn writeEvent(writer: anytype, data: []const u8) !void {
    try writer.writeAll("data: ");
    try writer.writeAll(data);
    try writer.writeAll("\n\n");
}

/// Write an SSE comment (often used as keep-alive).
pub fn writeComment(writer: anytype, comment: []const u8) !void {
    try writer.writeAll(": ");
    try writer.writeAll(comment);
    try writer.writeAll("\n\n");
}

/// Send SSE headers to the connection.
pub fn sendHeaders(stream: std.net.Stream) !void {
    const headers = 
        "HTTP/1.1 200 OK\r\n" ++
        "Content-Type: text/event-stream\r\n" ++
        "Cache-Control: no-cache\r\n" ++
        "Connection: keep-alive\r\n" ++
        "Transfer-Encoding: chunked\r\n" ++
        "\r\n";
    try stream.writeAll(headers);
}

/// Write a chunk in chunked transfer encoding.
pub fn writeChunk(stream: std.net.Stream, data: []const u8) !void {
    var buf: [32]u8 = undefined;
    const header = try std.fmt.bufPrint(&buf, "{x}\r\n", .{data.len});
    try stream.writeAll(header);
    try stream.writeAll(data);
    try stream.writeAll("\r\n");
}

/// Finish chunked transfer.
pub fn finishChunked(stream: std.net.Stream) !void {
    try stream.writeAll("0\r\n\r\n");
}
