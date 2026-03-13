const std = @import("std");
const mem = std.mem;
const os = std.posix;
const builtin = @import("builtin");

pub const ShellEngine = struct {
    allocator: std.mem.Allocator,
    working_dir: []u8,
    env: std.process.EnvMap,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .working_dir = try allocator.dupe(u8, "/data/data/org.dragun.pegasus/files"),
            .env = try std.process.getEnvMap(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.working_dir);
        self.allocator.destroy(self);
    }

    pub fn execute(self: *Self, command: []const u8, stdout_writer: anytype, stderr_writer: anytype) !void {
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer args.deinit();

        var it = mem.tokenize(u8, command, " ");
        while (it.next()) |arg| {
            try args.append(arg);
        }

        if (args.items.len == 0) return;

        const cmd = args.items[0];
        const argv = try args.toOwnedSlice();

        if (builtin.os.tag == .linux) {
            try self.executeLinux(cmd, argv, stdout_writer, stderr_writer);
        } else {
            try stdout_writer.print("Shell not supported on this platform\n", .{});
        }
    }

    fn executeLinux(self: *Self, cmd: []const u8, argv: []const []const u8, stdout_writer: anytype, stderr_writer: anytype) !void {
        if (mem.eql(u8, cmd, "cd")) {
            if (argv.len > 1) {
                self.allocator.free(self.working_dir);
                self.working_dir = try self.allocator.dupe(u8, argv[1]);
                try stdout_writer.print("Changed directory to {s}\n", .{argv[1]});
            } else {
                self.allocator.free(self.working_dir);
                self.working_dir = try self.allocator.dupe(u8, "/data/data/org.dragun.pegasus/files");
                try stdout_writer.print("Changed directory to ~\n", .{});
            }
            return;
        }

        if (mem.eql(u8, cmd, "pwd")) {
            try stdout_writer.print("{s}\n", .{self.working_dir});
            return;
        }

        if (mem.eql(u8, cmd, "echo")) {
            for (argv[1..]) |arg| {
                try stdout_writer.print("{s} ", .{arg});
            }
            try stdout_writer.print("\n", .{});
            return;
        }

        if (mem.eql(u8, cmd, "whoami")) {
            try stdout_writer.print("pegasus\n", .{});
            return;
        }

        if (mem.eql(u8, cmd, "date")) {
            const now = std.time.Timestamp.now();
            try stdout_writer.print("{}\n", .{now});
            return;
        }

        if (mem.eql(u8, cmd, "ls")) {
            var path = self.working_dir;
            if (argv.len > 1) {
                path = argv[1];
            }
            try self.listDirectory(path, stdout_writer);
            return;
        }

        if (mem.eql(u8, cmd, "cat")) {
            if (argv.len < 2) {
                try stderr_writer.print("Usage: cat <file>\n", .{});
                return;
            }
            try self.readFile(argv[1], stdout_writer);
            return;
        }

        if (mem.eql(u8, cmd, "agents")) {
            try stdout_writer.print("agents - List and manage OpenClaw agents\n", .{});
            try stdout_writer.print("Usage: agents [list|start <id>|stop <id>|status <id>]\n", .{});
            return;
        }

        if (mem.eql(u8, cmd, "help")) {
            try self.printHelp(stdout_writer);
            return;
        }

        try stdout_writer.print("Command not found: {s}\n", .{cmd});
    }

    fn listDirectory(self: *Self, path: []const u8, writer: anytype) !void {
        var dir = try std.fs.openDirAbsolute(path, .{});
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            try writer.print("{s}\n", .{entry.name});
        }
    }

    fn readFile(self: *Self, path: []const u8, writer: anytype) !void {
        const full_path = if (std.fs.path.isAbsolute(path)) path else std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.working_dir, path }) catch |e| {
            try writer.print("Error: {}\n", .{e});
            return;
        };
        defer if (!std.fs.path.isAbsolute(path)) self.allocator.free(full_path);

        const file = std.fs.openFileAbsolute(full_path, .{}) catch |e| {
            try writer.print("Error opening file: {}\n", .{e});
            return;
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);
        try writer.print("{s}", .{content});
    }

    fn printHelp(self: *Self, writer: anytype) !void {
        try writer.print(
            \\Pegasus Shell - Built-in commands:
            \\  cd <dir>     Change directory
            \\  pwd         Print working directory
            \\  ls [dir]    List directory contents
            \\  cat <file>  Display file contents
            \\  echo <text> Print text
            \\  whoami      Print current user
            \\  date        Print current timestamp
            \\  agents      OpenClaw agent management
            \\  help        Show this help
            \\
        , .{});
    }
};
