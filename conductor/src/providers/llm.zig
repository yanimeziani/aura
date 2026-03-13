const std = @import("std");
const Allocator = std.mem.Allocator;

/// LLM Provider abstraction
pub const Provider = enum {
    anthropic,
    openai,
    local,
};

/// Chat message
pub const ChatMessage = struct {
    role: Role,
    content: []const u8,

    pub const Role = enum {
        system,
        user,
        assistant,
    };
};

/// Completion request
pub const Request = struct {
    model: []const u8,
    messages: []const ChatMessage,
    max_tokens: u32 = 4096,
    temperature: f32 = 0.7,
    stream: bool = false,
};

/// Completion response
pub const Response = struct {
    content: []const u8,
    model: []const u8,
    usage: Usage,

    pub const Usage = struct {
        input_tokens: u32,
        output_tokens: u32,
    };
};

/// LLM Client
pub const Client = struct {
    allocator: Allocator,
    provider: Provider,
    api_key: []const u8,
    base_url: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, provider: Provider, api_key: []const u8) Self {
        const base_url = switch (provider) {
            .anthropic => "https://api.anthropic.com/v1",
            .openai => "https://api.openai.com/v1",
            .local => "http://localhost:11434/api",
        };

        return .{
            .allocator = allocator,
            .provider = provider,
            .api_key = api_key,
            .base_url = base_url,
        };
    }

    pub fn complete(self: *Self, request: Request) !Response {
        _ = self;
        _ = request;

        // HTTP client implementation
        // For now, return placeholder
        return .{
            .content = "LLM response placeholder",
            .model = "placeholder",
            .usage = .{ .input_tokens = 0, .output_tokens = 0 },
        };
    }

    pub fn stream(self: *Self, request: Request, callback: *const fn ([]const u8) void) !void {
        _ = self;
        _ = request;
        callback("streaming chunk");
    }
};

/// Model presets
pub const Models = struct {
    pub const claude_sonnet = "claude-sonnet-4-20250514";
    pub const claude_opus = "claude-opus-4-20250514";
    pub const gpt4o = "gpt-4o";
    pub const gpt4o_mini = "gpt-4o-mini";
    pub const local_llama = "llama3.2";
};

test "client init" {
    const allocator = std.testing.allocator;
    var client = Client.init(allocator, .anthropic, "test-key");
    try std.testing.expectEqual(Provider.anthropic, client.provider);
}
