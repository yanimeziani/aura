const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    while (true) {
        // Clear screen and reset cursor
        std.debug.print("\x1B[2J\x1B[H", .{});
        std.debug.print("=== \x1B[36;1m🔮 AURA COMMAND CENTER\x1B[0m ===\n\n", .{});
        
        // Fetch Systemctl Status
        var status_proc = std.process.Child.init(&[_][]const u8{"systemctl", "is-active", "aura_autopilot.service", "ai_pay.service", "ai_agency_web.service"}, allocator);
        status_proc.stdout_behavior = .Pipe;
        status_proc.stderr_behavior = .Ignore;
        _ = status_proc.spawn() catch |err| {
            std.debug.print("Failed to fetch status: {}\n", .{err});
        };
        
        const status_out = status_proc.stdout.?.readToEndAlloc(allocator, 1024 * 64) catch "";
        defer if (status_out.len > 0) allocator.free(status_out);
        _ = status_proc.wait() catch {};
        
        std.debug.print("\x1B[33m[ Daemons Status ]\x1B[0m\n", .{});
        var split = std.mem.splitScalar(u8, status_out, '\n');
        const services = [_][]const u8{"Autopilot  ", "Payment API", "Web UI     "};
        var i: usize = 0;
        while (split.next()) |line| {
            if (line.len == 0 or i >= 3) continue;
            const color = if (std.mem.eql(u8, line, "active")) "\x1B[32m" else "\x1B[31m";
            std.debug.print("  {s} : {s}{s}\x1B[0m\n", .{services[i], color, line});
            i += 1;
        }

        // Mesh Status (Real-time dashboard stub)
        std.debug.print("\n\x1B[33m[ Mesh & Traffic ]\x1B[0m\n", .{});
        std.debug.print("  Mesh Nodes : \x1B[32m4 Active\x1B[0m (LA, LDN, TYO, FRA)\n", .{});
        std.debug.print("  Traffic    : \x1B[36m1.2 MB/s\x1B[0m (In) / \x1B[35m450 KB/s\x1B[0m (Out)\n", .{});
        std.debug.print("  Handshake  : \x1B[32mNoise_IK [Ready]\x1B[0m\n", .{});

        std.debug.print("\n\x1B[33m[ Controls ]\x1B[0m\n", .{});
        std.debug.print("  \x1B[1m1.\x1B[0m Start Services\n", .{});
        std.debug.print("  \x1B[1m2.\x1B[0m Stop Services\n", .{});
        std.debug.print("  \x1B[1m3.\x1B[0m Run Vault Manager\n", .{});
        std.debug.print("  \x1B[1m4.\x1B[0m View Agent Logs (tail)\n", .{});
        std.debug.print("  \x1B[1m5.\x1B[0m Trigger Frontend Build\n", .{});
        std.debug.print("  \x1B[1m6.\x1B[0m Configure Webhooks\n", .{});
        std.debug.print("  \x1B[1m7.\x1B[0m View Mesh Details\n", .{});
        std.debug.print("  \x1B[1mq.\x1B[0m Quit to Shell\n\n", .{});
        std.debug.print("Select an option: ", .{});

        var buf: [16]u8 = undefined;
        const len = std.posix.read(std.posix.STDIN_FILENO, &buf) catch 0;
        if (len > 0) {
            const char = buf[0];
            if (char == 'q' or char == 'Q') {
                break;
            } else if (char == '1') {
                try exec(allocator, &[_][]const u8{"sudo", "systemctl", "start", "aura_autopilot.service", "ai_pay.service", "ai_agency_web.service"});
            } else if (char == '2') {
                try exec(allocator, &[_][]const u8{"sudo", "systemctl", "stop", "aura_autopilot.service", "ai_pay.service", "ai_agency_web.service"});
            } else if (char == '3') {
                try exec(allocator, &[_][]const u8{"python3", "/home/yani/Aura/vault/vault_manager.py"});
            } else if (char == '4') {
                try exec(allocator, &[_][]const u8{"less", "+F", "/home/yani/Aura/ai_agency_wealth/agency_metrics.log"});
            } else if (char == '5') {
                try exec(allocator, &[_][]const u8{"bash", "-c", "cd /home/yani/Aura/ai_agency_web && npm run build"});
            } else if (char == '6') {
                try exec(allocator, &[_][]const u8{"python3", "/home/yani/Aura/vault/vault_manager.py", "webhook"});
            } else if (char == '7') {
                try exec(allocator, &[_][]const u8{"curl", "-s", "http://localhost:9000/mesh"});
            }
        } else {
            break;
        }
    }
    
    std.debug.print("\n\x1B[36mExiting Aura TUI.\x1B[0m\n", .{});
}

fn exec(allocator: std.mem.Allocator, argv: []const []const u8) !void {
    // Clear screen before executing
    std.debug.print("\x1B[2J\x1B[H", .{});
    var proc = std.process.Child.init(argv, allocator);
    _ = try proc.spawnAndWait();
    
    std.debug.print("\n\x1B[32m[Command finished. Press Enter to continue...]\x1B[0m", .{});
    var buf: [1]u8 = undefined;
    _ = std.posix.read(std.posix.STDIN_FILENO, &buf) catch 0;
}
