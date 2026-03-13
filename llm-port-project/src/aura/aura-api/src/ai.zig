//! Groq/Gemini HTTP streaming client — aura-api.
//! Zig 0.15.2 + std only.

const std = @import("std");
const http = std.http;

pub const Provider = enum {
    groq,
    gemini,

    pub fn fromString(s: []const u8) ?Provider {
        if (std.mem.eql(u8, s, "groq")) return .groq;
        if (std.mem.eql(u8, s, "gemini")) return .gemini;
        return null;
    }
};

pub const Message = struct {
    role: []const u8,
    content: []const u8,
};

pub const ChatOptions = struct {
    model: []const u8,
    messages: []const Message,
    temperature: f32 = 0.7,
    max_tokens: ?u32 = null,
    stream: bool = true,
};

pub const StreamError = error{
    MissingApiKey,
    HttpError,
    InvalidResponse,
};

/// Stream a chat completion from the specified provider.
/// The `on_chunk` callback is called for each received SSE data chunk (for Groq) 
/// or each JSON part (for Gemini).
pub fn streamChat(
    allocator: std.mem.Allocator,
    provider: Provider,
    options: ChatOptions,
    on_chunk: anytype,
) !void {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const api_key = std.posix.getenv(if (provider == .groq) "GROQ_API_KEY" else "GEMINI_API_KEY") orelse return error.MissingApiKey;

    const uri_str = if (provider == .groq) 
        "https://api.groq.com/openai/v1/chat/completions" 
    else 
        try std.fmt.allocPrint(allocator, "https://generativelanguage.googleapis.com/v1beta/models/{s}:streamGenerateContent?alt=sse&key={s}", .{ options.model, api_key });
    defer if (provider == .gemini) allocator.free(uri_str);

    const uri = try std.Uri.parse(uri_str);

    var extra_headers = std.ArrayList(http.Header).init(allocator);
    defer {
        for (extra_headers.items) |h| allocator.free(h.value);
        extra_headers.deinit();
    }

    if (provider == .groq) {
        const auth = try std.fmt.allocPrint(allocator, "Bearer {s}", .{api_key});
        try extra_headers.append(.{ .name = "authorization", .value = auth });
    }

    // Prepare body
    var body_buf = std.ArrayList(u8).init(allocator);
    defer body_buf.deinit();

    if (provider == .groq) {
        try std.json.stringify(.{
            .model = options.model,
            .messages = options.messages,
            .temperature = options.temperature,
            .max_tokens = options.max_tokens,
            .stream = options.stream,
        }, .{}, body_buf.writer());
    } else {
        // Gemini format
        try body_buf.appendSlice("{\"contents\":[");
        for (options.messages, 0..) |m, i| {
            if (i > 0) try body_buf.appendSlice(",");
            try body_buf.appendSlice("{\"role\":\"");
            try body_buf.appendSlice(if (std.mem.eql(u8, m.role, "assistant")) "model" else "user");
            try body_buf.appendSlice("\",\"parts\":[{\"text\":");
            try std.json.encodeJsonString(m.content, .{}, body_buf.writer());
            try body_buf.appendSlice("}]}");
        }
        try body_buf.appendSlice("],\"generationConfig\":{");
        try std.fmt.format(body_buf.writer(), "\"temperature\":{d}", .{options.temperature});
        if (options.max_tokens) |mt| {
            try std.fmt.format(body_buf.writer(), ",\"maxOutputTokens\":{d}", .{mt});
        }
        try body_buf.appendSlice("}}");
    }

    var req = try client.open(.POST, uri, .{
        .server_header_buffer = try allocator.alloc(u8, 16 * 1024),
        .extra_headers = extra_headers.items,
        .headers = .{
            .content_type = .{ .override = "application/json" },
        },
    });
    defer req.deinit();
    defer allocator.free(req.server_header_buffer.?);

    req.transfer_encoding = .{ .content_length = body_buf.items.len };
    try req.send();
    try req.writeAll(body_buf.items);
    try req.finish();

    try req.wait();

    if (req.response.status != .ok) {
        return error.HttpError;
    }

    var reader = req.reader();
    var chunk_buf: [4096]u8 = undefined;
    while (true) {
        const n = try reader.read(&chunk_buf);
        if (n == 0) break;
        try on_chunk(chunk_buf[0..n]) catch |err| {
            std.debug.print("on_chunk error: {}\n", .{err});
            return err;
        };
    }
}
