const std = @import("std");

const Mode = enum {
    codex,
    gemini,
    claude,

    fn fromString(raw: []const u8) ?Mode {
        if (std.ascii.eqlIgnoreCase(raw, "codex")) return .codex;
        if (std.ascii.eqlIgnoreCase(raw, "gemini")) return .gemini;
        if (std.ascii.eqlIgnoreCase(raw, "claude")) return .claude;
        return null;
    }

    fn label(self: Mode) []const u8 {
        return switch (self) {
            .codex => "codex",
            .gemini => "gemini",
            .claude => "claude",
        };
    }

    fn systemPrompt(self: Mode) []const u8 {
        return switch (self) {
            .codex =>
            \\You are an in-house coding terminal. Be direct, implementation-first, and concise.
            \\Prefer actionable code and exact commands. Assume local sovereign infrastructure.
            ,
            .gemini =>
            \\You are an in-house research and synthesis terminal. Be structured, analytical, and clear.
            \\Prefer concise explanations, tradeoffs, and next steps.
            ,
            .claude =>
            \\You are an in-house architecture and writing terminal. Be careful, coherent, and high-signal.
            \\Prefer polished reasoning, but stay concise and practical.
            ,
        };
    }
};

const Message = struct {
    role: []u8,
    content: []u8,
};

const Config = struct {
    mode: Mode,
    model: []const u8,
    host: []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cfg = Config{
        .mode = parseModeArg() orelse .codex,
        .model = std.posix.getenv("NEXA_LOCAL_MODEL") orelse "qwen2.5:1.5b",
        .host = std.posix.getenv("OLLAMA_HOST") orelse "http://127.0.0.1:11434",
    };

    var history = std.ArrayList(Message).empty;
    defer {
        for (history.items) |msg| {
            allocator.free(msg.role);
            allocator.free(msg.content);
        }
        history.deinit(allocator);
    }

    try appendMessage(allocator, &history, "system", cfg.mode.systemPrompt());

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try printBanner(stdout, cfg);
    try stdout.flush();

    var stdin_buffer: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    while (true) {
        try stdout.print("\n[{s}:{s}] > ", .{ cfg.mode.label(), cfg.model });
        try stdout.flush();

        const raw_line = stdin.takeDelimiterExclusive('\n') catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        const trimmed = std.mem.trim(u8, raw_line, " \r\t");
        if (trimmed.len == 0) continue;

        if (trimmed[0] == '/') {
            const should_continue = try handleCommand(allocator, stdout, &history, &cfg, trimmed);
            try stdout.flush();
            if (!should_continue) break;
            continue;
        }

        try appendMessage(allocator, &history, "user", trimmed);
        const reply = requestChat(allocator, cfg, history.items) catch |err| {
            try stdout.print("\nerror: {}\n", .{err});
            try stdout.flush();
            _ = history.pop();
            continue;
        };
        defer allocator.free(reply);

        try appendMessage(allocator, &history, "assistant", reply);
        try stdout.print("\n{s}\n", .{reply});
        try stdout.flush();
    }
}

fn parseModeArg() ?Mode {
    var args = std.process.args();
    _ = args.skip();
    if (args.next()) |arg| {
        return Mode.fromString(arg);
    }
    return null;
}

fn printBanner(stdout: *std.Io.Writer, cfg: Config) !void {
    try stdout.print(
        \\AURA LOCAL TERMINAL
        \\mode:  {s}
        \\model: {s}
        \\host:  {s}
        \\
        \\Commands:
        \\  /help                  show commands
        \\  /mode codex|gemini|claude
        \\  /model <ollama-model>
        \\  /clear                 reset conversation
        \\  /status                show current config
        \\  /quit
        \\
    , .{ cfg.mode.label(), cfg.model, cfg.host });
}

fn handleCommand(
    allocator: std.mem.Allocator,
    stdout: *std.Io.Writer,
    history: *std.ArrayList(Message),
    cfg: *Config,
    line: []const u8,
) !bool {
    if (std.mem.eql(u8, line, "/quit")) return false;
    if (std.mem.eql(u8, line, "/help")) {
        try stdout.print(
            \\commands:
            \\  /help
            \\  /mode codex|gemini|claude
            \\  /model <ollama-model>
            \\  /clear
            \\  /status
            \\  /quit
            \\
        , .{});
        return true;
    }
    if (std.mem.eql(u8, line, "/status")) {
        try stdout.print("mode={s} model={s} host={s}\n", .{ cfg.mode.label(), cfg.model, cfg.host });
        return true;
    }
    if (std.mem.eql(u8, line, "/clear")) {
        for (history.items) |msg| {
            allocator.free(msg.role);
            allocator.free(msg.content);
        }
        history.clearRetainingCapacity();
        try appendMessage(allocator, history, "system", cfg.mode.systemPrompt());
        try stdout.print("conversation cleared\n", .{});
        return true;
    }
    if (std.mem.startsWith(u8, line, "/mode ")) {
        const raw = std.mem.trim(u8, line["/mode ".len..], " \t");
        const mode = Mode.fromString(raw) orelse {
            try stdout.print("unknown mode: {s}\n", .{raw});
            return true;
        };
        cfg.mode = mode;
        for (history.items) |msg| {
            allocator.free(msg.role);
            allocator.free(msg.content);
        }
        history.clearRetainingCapacity();
        try appendMessage(allocator, history, "system", cfg.mode.systemPrompt());
        try stdout.print("mode set to {s}\n", .{cfg.mode.label()});
        return true;
    }
    if (std.mem.startsWith(u8, line, "/model ")) {
        const raw = std.mem.trim(u8, line["/model ".len..], " \t");
        if (raw.len == 0) {
            try stdout.print("missing model name\n", .{});
            return true;
        }
        cfg.model = try allocator.dupe(u8, raw);
        try stdout.print("model set to {s}\n", .{cfg.model});
        return true;
    }

    try stdout.print("unknown command: {s}\n", .{line});
    return true;
}

fn appendMessage(
    allocator: std.mem.Allocator,
    history: *std.ArrayList(Message),
    role: []const u8,
    content: []const u8,
) !void {
    try history.append(allocator, .{
        .role = try allocator.dupe(u8, role),
        .content = try allocator.dupe(u8, content),
    });
}

fn requestChat(
    allocator: std.mem.Allocator,
    cfg: Config,
    history: []const Message,
) ![]u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    return requestChatInner(allocator, &client, cfg, history);
}

fn requestChatInner(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    cfg: Config,
    history: []const Message,
) ![]u8 {
    var body = std.ArrayList(u8).empty;
    defer body.deinit(allocator);
    try buildRequestBody(allocator, &body, cfg, history);

    const url = try std.fmt.allocPrint(allocator, "{s}/api/chat", .{cfg.host});
    defer allocator.free(url);

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .payload = body.items,
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
        .response_writer = &aw.writer,
    });

    if (result.status != .ok) return error.UpstreamError;

    const response_body = aw.writer.buffer[0..aw.writer.end];
    return extractAssistantContent(allocator, response_body);
}

fn buildRequestBody(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    cfg: Config,
    history: []const Message,
) !void {
    try out.appendSlice(allocator, "{\"model\":");
    try appendJsonString(allocator, out, cfg.model);
    try out.appendSlice(allocator, ",\"stream\":false,\"options\":{\"temperature\":0.2,\"num_predict\":192},\"messages\":[");
    for (history, 0..) |msg, i| {
        if (i != 0) try out.appendSlice(allocator, ",");
        try out.appendSlice(allocator, "{\"role\":");
        try appendJsonString(allocator, out, msg.role);
        try out.appendSlice(allocator, ",\"content\":");
        try appendJsonString(allocator, out, msg.content);
        try out.appendSlice(allocator, "}");
    }
    try out.appendSlice(allocator, "]}");
}

fn appendJsonString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: []const u8) !void {
    try out.append(allocator, '"');
    for (value) |c| {
        switch (c) {
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '"' => try out.appendSlice(allocator, "\\\""),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            else => try out.append(allocator, c),
        }
    }
    try out.append(allocator, '"');
}

fn extractAssistantContent(allocator: std.mem.Allocator, body: []const u8) ![]u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();

    const root = parsed.value;
    const obj = root.object;
    const message = obj.get("message") orelse return error.InvalidResponse;
    if (message != .object) return error.InvalidResponse;
    const content = message.object.get("content") orelse return error.InvalidResponse;
    if (content != .string) return error.InvalidResponse;
    return allocator.dupe(u8, content.string);
}
