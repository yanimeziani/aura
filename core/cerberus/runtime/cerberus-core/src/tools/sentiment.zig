const std = @import("std");
const root = @import("root.zig");
const Tool = root.Tool;
const ToolResult = root.ToolResult;
const JsonObjectMap = std.StringArrayHashMap(std.json.Value);

pub const SentimentTool = struct {
    pub const tool_name = "sentiment_analysis";
    pub const tool_description = "Perform ultra-fast, local emotional and sentimental analysis on text to eliminate supply chain risks from third-party NLP APIs. Returns a sentiment score from -1.0 (very negative) to 1.0 (very positive) and a categorical emotional state.";
    pub const tool_params =
        \\{
        \\  "type": "object",
        \\  "properties": {
        \\    "text": {
        \\      "type": "string",
        \\      "description": "The text to analyze."
        \\    }
        \\  },
        \\  "required": ["text"]
        \\}
    ;

    pub const vtable = root.ToolVTable(@This());

    pub fn tool(self: *@This()) Tool {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    pub fn execute(_: *@This(), allocator: std.mem.Allocator, args: JsonObjectMap) !ToolResult {
        const text = root.getString(args, "text") orelse return ToolResult.fail("Missing required parameter: text");

        var score: f32 = 0.0;
        var words: usize = 0;

        // Basic ultra-fast lexicon approach to cut external dependencies.
        // A full implementation would load a compiled binary dictionary.
        var it = std.mem.tokenizeAny(u8, text, " \t\n\r.,!?;:()[]\"'");
        while (it.next()) |word| {
            // Very rudimentary scoring for demonstration of the ultra-fast native path
            if (std.ascii.eqlIgnoreCase(word, "good") or 
                std.ascii.eqlIgnoreCase(word, "great") or
                std.ascii.eqlIgnoreCase(word, "excellent") or
                std.ascii.eqlIgnoreCase(word, "happy") or
                std.ascii.eqlIgnoreCase(word, "love") or
                std.ascii.eqlIgnoreCase(word, "positive")) {
                score += 1.0;
            } else if (std.ascii.eqlIgnoreCase(word, "bad") or 
                       std.ascii.eqlIgnoreCase(word, "terrible") or
                       std.ascii.eqlIgnoreCase(word, "awful") or
                       std.ascii.eqlIgnoreCase(word, "sad") or
                       std.ascii.eqlIgnoreCase(word, "hate") or
                       std.ascii.eqlIgnoreCase(word, "negative") or
                       std.ascii.eqlIgnoreCase(word, "angry")) {
                score -= 1.0;
            }
            words += 1;
        }

        var normalized_score: f32 = 0.0;
        if (words > 0) {
            // Keep between -1.0 and 1.0
            normalized_score = @max(-1.0, @min(1.0, score / @as(f32, @floatFromInt(words)) * 5.0));
        }

        const emotion = if (normalized_score > 0.5) "Joy / Positive"
                       else if (normalized_score < -0.5) "Anger / Negative"
                       else if (normalized_score > 0.1) "Content"
                       else if (normalized_score < -0.1) "Frustrated"
                       else "Neutral";

        const out = try std.fmt.allocPrint(allocator, 
            \\{{
            \\  "score": {d:.3},
            \\  "emotion": "{s}",
            \\  "words_analyzed": {d},
            \\  "supply_chain_risk": "zero"
            \\}}
        , .{ normalized_score, emotion, words });
        defer allocator.free(out);

        return ToolResult.ok(out);
    }
};

test "sentiment analysis tool execution" {
    var tool_inst = SentimentTool{};
    var t = tool_inst.tool();

    const expected_name = "sentiment_analysis";
    try std.testing.expectEqualStrings(expected_name, t.name());

    var args = JsonObjectMap.init(std.testing.allocator);
    defer args.deinit();

    try args.put("text", std.json.Value{ .string = "This is a great and happy test." });
    
    const result = try t.execute(std.testing.allocator, args);

    try std.testing.expect(result.success);
    // Score should be positive
    try std.testing.expect(std.mem.indexOf(u8, result.output, "Joy / Positive") != null or std.mem.indexOf(u8, result.output, "Content") != null);
}
