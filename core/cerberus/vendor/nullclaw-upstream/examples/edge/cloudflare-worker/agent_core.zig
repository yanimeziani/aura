const std = @import("std");

/// Response policy returned by `choose_policy`.
/// 0 = concise, 1 = detailed, 2 = urgent.
pub const Policy = enum(u32) {
    concise = 0,
    detailed = 1,
    urgent = 2,
};

/// Tiny WASM decision core: host computes simple text features, core returns policy.
/// This keeps networking/secrets in edge host while logic stays in WASM.
pub export fn choose_policy(
    text_len: u32,
    has_question: u32,
    has_urgent_keyword: u32,
    has_code_hint: u32,
) u32 {
    const urgent_bonus: u32 = if (text_len > 900) 1 else 0;
    const detailed_bonus: u32 = if (text_len > 260) 1 else 0;
    const urgent_score: u32 = has_urgent_keyword * 3 + urgent_bonus;
    const detailed_score: u32 = has_question * 2 + has_code_hint * 2 + detailed_bonus;

    if (urgent_score >= 3) return @intFromEnum(Policy.urgent);
    if (detailed_score >= 3) return @intFromEnum(Policy.detailed);
    return @intFromEnum(Policy.concise);
}

test "choose_policy selects urgent" {
    try std.testing.expectEqual(@as(u32, @intFromEnum(Policy.urgent)), choose_policy(80, 1, 1, 0));
}

test "choose_policy selects detailed" {
    try std.testing.expectEqual(@as(u32, @intFromEnum(Policy.detailed)), choose_policy(350, 1, 0, 0));
}

test "choose_policy defaults to concise" {
    try std.testing.expectEqual(@as(u32, @intFromEnum(Policy.concise)), choose_policy(30, 0, 0, 0));
}
