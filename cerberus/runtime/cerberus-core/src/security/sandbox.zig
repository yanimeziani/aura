const std = @import("std");

/// Sandbox backend vtable interface for OS-level isolation.
/// In Zig, we use a vtable pattern instead of Rust's trait objects.
pub const Sandbox = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Wrap a command with sandbox protection.
        /// Returns a modified argv or error.
        wrapCommand: *const fn (ctx: *anyopaque, argv: []const []const u8, buf: [][]const u8) anyerror![]const []const u8,
        /// Check if this sandbox backend is available on the current platform
        isAvailable: *const fn (ctx: *anyopaque) bool,
        /// Human-readable name of this sandbox backend
        name: *const fn (ctx: *anyopaque) []const u8,
        /// Description of what this sandbox provides
        description: *const fn (ctx: *anyopaque) []const u8,
    };

    pub fn wrapCommand(self: Sandbox, argv: []const []const u8, buf: [][]const u8) ![]const []const u8 {
        return self.vtable.wrapCommand(self.ptr, argv, buf);
    }

    pub fn isAvailable(self: Sandbox) bool {
        return self.vtable.isAvailable(self.ptr);
    }

    pub fn name(self: Sandbox) []const u8 {
        return self.vtable.name(self.ptr);
    }

    pub fn description(self: Sandbox) []const u8 {
        return self.vtable.description(self.ptr);
    }
};

/// No-op sandbox (always available, provides no additional isolation)
pub const NoopSandbox = struct {
    pub const sandbox_vtable = Sandbox.VTable{
        .wrapCommand = wrapCommand,
        .isAvailable = isAvailable,
        .name = getName,
        .description = getDescription,
    };

    pub fn sandbox(self: *NoopSandbox) Sandbox {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &sandbox_vtable,
        };
    }

    fn wrapCommand(_: *anyopaque, argv: []const []const u8, _: [][]const u8) ![]const []const u8 {
        // Pass through unchanged
        return argv;
    }

    fn isAvailable(_: *anyopaque) bool {
        return true;
    }

    fn getName(_: *anyopaque) []const u8 {
        return "none";
    }

    fn getDescription(_: *anyopaque) []const u8 {
        return "No sandboxing (application-layer security only)";
    }
};

/// Create a noop sandbox (default fallback)
pub fn createNoopSandbox() NoopSandbox {
    return .{};
}

/// Re-export detect module's createSandbox for convenience.
pub const createSandbox = @import("detect.zig").createSandbox;
pub const SandboxBackend = @import("detect.zig").SandboxBackend;
pub const SandboxStorage = @import("detect.zig").SandboxStorage;
pub const detectAvailable = @import("detect.zig").detectAvailable;
pub const AvailableBackends = @import("detect.zig").AvailableBackends;

// ── Tests ──────────────────────────────────────────────────────────────
