//! SQLite disabled shim.
//!
//! Provides minimal sqlite3 symbols/types so modules can compile when
//! SQLite runtime support is excluded from the build (for example, when
//! `-Dengines` does not include sqlite/lucid/lancedb).

const std = @import("std");
const builtin = @import("builtin");
const root = @import("../root.zig");
const Memory = root.Memory;
const MemoryCategory = root.MemoryCategory;
const MemoryEntry = root.MemoryEntry;

pub const c = struct {
    pub const sqlite3 = opaque {};
    pub const sqlite3_stmt = opaque {};
    pub const sqlite3_destructor_type = ?*const fn (?*anyopaque) callconv(.c) void;

    pub const SQLITE_OK: c_int = 0;
    pub const SQLITE_ERROR: c_int = 1;
    pub const SQLITE_ROW: c_int = 100;
    pub const SQLITE_DONE: c_int = 101;
    pub const SQLITE_NULL: c_int = 5;

    pub const SQLITE_OPEN_READONLY: c_int = 0x00000001;
    pub const SQLITE_OPEN_READWRITE: c_int = 0x00000002;
    pub const SQLITE_OPEN_CREATE: c_int = 0x00000004;
    pub const SQLITE_OPEN_NOMUTEX: c_int = 0x00008000;

    pub fn sqlite3_open(_: [*c]const u8, db: *?*sqlite3) c_int {
        db.* = null;
        return SQLITE_ERROR;
    }

    pub fn sqlite3_open_v2(_: [*c]const u8, db: *?*sqlite3, _: c_int, _: ?[*c]const u8) c_int {
        db.* = null;
        return SQLITE_ERROR;
    }

    pub fn sqlite3_close(_: ?*sqlite3) c_int {
        return SQLITE_OK;
    }

    pub fn sqlite3_exec(_: ?*sqlite3, _: [*c]const u8, _: ?*const anyopaque, _: ?*anyopaque, err_msg: ?*[*c]u8) c_int {
        if (err_msg) |p| p.* = null;
        return SQLITE_ERROR;
    }

    pub fn sqlite3_free(_: ?[*c]u8) void {}

    pub fn sqlite3_prepare_v2(_: ?*sqlite3, _: [*c]const u8, _: c_int, stmt: *?*sqlite3_stmt, _: ?*?[*c]const u8) c_int {
        stmt.* = null;
        return SQLITE_ERROR;
    }

    pub fn sqlite3_step(_: ?*sqlite3_stmt) c_int {
        return SQLITE_DONE;
    }

    pub fn sqlite3_finalize(_: ?*sqlite3_stmt) c_int {
        return SQLITE_OK;
    }

    pub fn sqlite3_bind_text(_: ?*sqlite3_stmt, _: c_int, _: [*c]const u8, _: c_int, _: sqlite3_destructor_type) c_int {
        return SQLITE_ERROR;
    }

    pub fn sqlite3_bind_blob(_: ?*sqlite3_stmt, _: c_int, _: ?*const anyopaque, _: c_int, _: sqlite3_destructor_type) c_int {
        return SQLITE_ERROR;
    }

    pub fn sqlite3_bind_int(_: ?*sqlite3_stmt, _: c_int, _: c_int) c_int {
        return SQLITE_ERROR;
    }

    pub fn sqlite3_bind_int64(_: ?*sqlite3_stmt, _: c_int, _: i64) c_int {
        return SQLITE_ERROR;
    }

    pub fn sqlite3_bind_double(_: ?*sqlite3_stmt, _: c_int, _: f64) c_int {
        return SQLITE_ERROR;
    }

    pub fn sqlite3_bind_null(_: ?*sqlite3_stmt, _: c_int) c_int {
        return SQLITE_ERROR;
    }

    pub fn sqlite3_column_text(_: ?*sqlite3_stmt, _: c_int) [*c]const u8 {
        return @ptrFromInt(0);
    }

    pub fn sqlite3_column_blob(_: ?*sqlite3_stmt, _: c_int) ?*const anyopaque {
        return null;
    }

    pub fn sqlite3_column_bytes(_: ?*sqlite3_stmt, _: c_int) c_int {
        return 0;
    }

    pub fn sqlite3_column_int(_: ?*sqlite3_stmt, _: c_int) c_int {
        return 0;
    }

    pub fn sqlite3_column_int64(_: ?*sqlite3_stmt, _: c_int) i64 {
        return 0;
    }

    pub fn sqlite3_column_double(_: ?*sqlite3_stmt, _: c_int) f64 {
        return 0;
    }

    pub fn sqlite3_column_type(_: ?*sqlite3_stmt, _: c_int) c_int {
        return SQLITE_NULL;
    }

    pub fn sqlite3_changes(_: ?*sqlite3) c_int {
        return 0;
    }
};

pub const SQLITE_STATIC: c.sqlite3_destructor_type = null;

pub const SqliteMemory = struct {
    db: ?*c.sqlite3 = null,
    allocator: std.mem.Allocator,
    owns_self: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, _: [*:0]const u8) !SqliteMemory {
        _ = allocator;
        if (builtin.is_test) return error.SkipZigTest;
        return error.SqliteDisabled;
    }

    pub fn deinit(_: *SqliteMemory) void {}

    fn implName(_: *anyopaque) []const u8 {
        return "sqlite";
    }

    fn implStore(_: *anyopaque, _: []const u8, _: []const u8, _: MemoryCategory, _: ?[]const u8) anyerror!void {
        return error.SqliteDisabled;
    }

    fn implRecall(_: *anyopaque, _: std.mem.Allocator, _: []const u8, _: usize, _: ?[]const u8) anyerror![]MemoryEntry {
        return error.SqliteDisabled;
    }

    fn implGet(_: *anyopaque, _: std.mem.Allocator, _: []const u8) anyerror!?MemoryEntry {
        return error.SqliteDisabled;
    }

    fn implList(_: *anyopaque, _: std.mem.Allocator, _: ?MemoryCategory, _: ?[]const u8) anyerror![]MemoryEntry {
        return error.SqliteDisabled;
    }

    fn implForget(_: *anyopaque, _: []const u8) anyerror!bool {
        return error.SqliteDisabled;
    }

    fn implCount(_: *anyopaque) anyerror!usize {
        return error.SqliteDisabled;
    }

    fn implHealthCheck(_: *anyopaque) bool {
        return false;
    }

    fn implDeinit(ptr: *anyopaque) void {
        const self_: *Self = @ptrCast(@alignCast(ptr));
        self_.deinit();
        if (self_.owns_self) {
            self_.allocator.destroy(self_);
        }
    }

    pub const vtable = Memory.VTable{
        .name = &implName,
        .store = &implStore,
        .recall = &implRecall,
        .get = &implGet,
        .list = &implList,
        .forget = &implForget,
        .count = &implCount,
        .healthCheck = &implHealthCheck,
        .deinit = &implDeinit,
    };

    pub fn memory(self: *Self) Memory {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    pub fn saveMessage(_: *Self, _: []const u8, _: []const u8, _: []const u8) !void {
        return error.SqliteDisabled;
    }

    pub fn loadMessages(_: *Self, _: std.mem.Allocator, _: []const u8) ![]root.MessageEntry {
        return error.SqliteDisabled;
    }

    pub fn clearMessages(_: *Self, _: []const u8) !void {
        return error.SqliteDisabled;
    }

    pub fn clearAutoSaved(_: *Self, _: ?[]const u8) !void {
        return error.SqliteDisabled;
    }

    fn implSessionSaveMessage(ptr: *anyopaque, session_id: []const u8, role: []const u8, content: []const u8) anyerror!void {
        const self_: *Self = @ptrCast(@alignCast(ptr));
        return self_.saveMessage(session_id, role, content);
    }

    fn implSessionLoadMessages(ptr: *anyopaque, allocator: std.mem.Allocator, session_id: []const u8) anyerror![]root.MessageEntry {
        const self_: *Self = @ptrCast(@alignCast(ptr));
        return self_.loadMessages(allocator, session_id);
    }

    fn implSessionClearMessages(ptr: *anyopaque, session_id: []const u8) anyerror!void {
        const self_: *Self = @ptrCast(@alignCast(ptr));
        return self_.clearMessages(session_id);
    }

    fn implSessionClearAutoSaved(ptr: *anyopaque, session_id: ?[]const u8) anyerror!void {
        const self_: *Self = @ptrCast(@alignCast(ptr));
        return self_.clearAutoSaved(session_id);
    }

    const session_vtable = root.SessionStore.VTable{
        .saveMessage = &implSessionSaveMessage,
        .loadMessages = &implSessionLoadMessages,
        .clearMessages = &implSessionClearMessages,
        .clearAutoSaved = &implSessionClearAutoSaved,
    };

    pub fn sessionStore(self: *Self) root.SessionStore {
        return .{ .ptr = @ptrCast(self), .vtable = &session_vtable };
    }

    pub fn reindex(_: *Self) !void {
        return error.SqliteDisabled;
    }
};
