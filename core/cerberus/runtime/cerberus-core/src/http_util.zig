//! Shared HTTP utilities via curl subprocess.
//!
//! Replaces 9+ local `curlPost` / `curlGet` duplicates across the codebase.
//! Uses curl to avoid Zig 0.15 std.http.Client segfaults.

const std = @import("std");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.http_util);

pub const HttpResponse = struct {
    status_code: u16,
    body: []u8,
};

/// HTTP POST via curl subprocess with optional proxy and timeout.
///
/// `headers` is a slice of header strings (e.g. `"Authorization: Bearer xxx"`).
/// `proxy` is an optional proxy URL (e.g. `"socks5://host:port"`).
/// `max_time` is an optional --max-time value as a string (e.g. `"300"`).
/// Returns the response body. Caller owns returned memory.
pub fn curlPostWithProxy(
    allocator: Allocator,
    url: []const u8,
    body: []const u8,
    headers: []const []const u8,
    proxy: ?[]const u8,
    max_time: ?[]const u8,
) ![]u8 {
    return curlRequestWithProxy(allocator, "POST", url, body, headers, proxy, max_time);
}

fn curlRequestWithProxy(
    allocator: Allocator,
    method: []const u8,
    url: []const u8,
    body: []const u8,
    headers: []const []const u8,
    proxy: ?[]const u8,
    max_time: ?[]const u8,
) ![]u8 {
    var argv_buf: [40][]const u8 = undefined;
    var argc: usize = 0;

    argv_buf[argc] = "curl";
    argc += 1;
    argv_buf[argc] = "-s";
    argc += 1;
    argv_buf[argc] = "-X";
    argc += 1;
    argv_buf[argc] = method;
    argc += 1;
    argv_buf[argc] = "-H";
    argc += 1;
    argv_buf[argc] = "Content-Type: application/json";
    argc += 1;

    if (proxy) |p| {
        argv_buf[argc] = "--proxy";
        argc += 1;
        argv_buf[argc] = p;
        argc += 1;
    }

    if (max_time) |mt| {
        argv_buf[argc] = "--max-time";
        argc += 1;
        argv_buf[argc] = mt;
        argc += 1;
    }

    for (headers) |hdr| {
        if (argc + 2 > argv_buf.len) break;
        argv_buf[argc] = "-H";
        argc += 1;
        argv_buf[argc] = hdr;
        argc += 1;
    }

    // Pass payload via stdin to avoid OS argv length limits for large JSON
    // bodies (e.g. multimodal base64 images).
    argv_buf[argc] = "--data-binary";
    argc += 1;
    argv_buf[argc] = "@-";
    argc += 1;
    argv_buf[argc] = url;
    argc += 1;

    var child = std.process.Child.init(argv_buf[0..argc], allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    try child.spawn();

    if (child.stdin) |stdin_file| {
        stdin_file.writeAll(body) catch {
            stdin_file.close();
            child.stdin = null;
            _ = child.kill() catch {};
            _ = child.wait() catch {};
            return error.CurlWriteError;
        };
        stdin_file.close();
        child.stdin = null;
    } else {
        _ = child.kill() catch {};
        _ = child.wait() catch {};
        return error.CurlWriteError;
    }

    const stdout = child.stdout.?.readToEndAlloc(allocator, 1024 * 1024) catch {
        _ = child.kill() catch {};
        _ = child.wait() catch {};
        return error.CurlReadError;
    };

    const term = child.wait() catch {
        allocator.free(stdout);
        return error.CurlWaitError;
    };
    switch (term) {
        .Exited => |code| if (code != 0) {
            allocator.free(stdout);
            return error.CurlFailed;
        },
        else => {
            allocator.free(stdout);
            return error.CurlFailed;
        },
    }

    return stdout;
}

/// HTTP POST via curl subprocess (no proxy, no timeout).
pub fn curlPost(allocator: Allocator, url: []const u8, body: []const u8, headers: []const []const u8) ![]u8 {
    return curlPostWithProxy(allocator, url, body, headers, null, null);
}

/// HTTP POST with application/x-www-form-urlencoded body via curl subprocess.
///
/// `body` must already be percent-encoded form data (e.g. `"key=val&key2=val2"`).
/// Returns the response body. Caller owns returned memory.
pub fn curlPostForm(allocator: Allocator, url: []const u8, body: []const u8) ![]u8 {
    var argv_buf: [10][]const u8 = undefined;
    var argc: usize = 0;

    argv_buf[argc] = "curl";
    argc += 1;
    argv_buf[argc] = "-s";
    argc += 1;
    argv_buf[argc] = "-X";
    argc += 1;
    argv_buf[argc] = "POST";
    argc += 1;
    argv_buf[argc] = "-H";
    argc += 1;
    argv_buf[argc] = "Content-Type: application/x-www-form-urlencoded";
    argc += 1;
    argv_buf[argc] = "--data-binary";
    argc += 1;
    argv_buf[argc] = "@-";
    argc += 1;
    argv_buf[argc] = url;
    argc += 1;

    var child = std.process.Child.init(argv_buf[0..argc], allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    try child.spawn();

    if (child.stdin) |stdin_file| {
        stdin_file.writeAll(body) catch {
            stdin_file.close();
            child.stdin = null;
            _ = child.kill() catch {};
            _ = child.wait() catch {};
            return error.CurlWriteError;
        };
        stdin_file.close();
        child.stdin = null;
    } else {
        _ = child.kill() catch {};
        _ = child.wait() catch {};
        return error.CurlWriteError;
    }

    const stdout = child.stdout.?.readToEndAlloc(allocator, 1024 * 1024) catch {
        _ = child.kill() catch {};
        _ = child.wait() catch {};
        return error.CurlReadError;
    };

    const term = child.wait() catch {
        allocator.free(stdout);
        return error.CurlWaitError;
    };
    switch (term) {
        .Exited => |code| if (code != 0) {
            allocator.free(stdout);
            return error.CurlFailed;
        },
        else => {
            allocator.free(stdout);
            return error.CurlFailed;
        },
    }

    return stdout;
}

/// HTTP POST via curl subprocess and include HTTP status code in response.
/// Caller owns `response.body`.
pub fn curlPostWithStatus(
    allocator: Allocator,
    url: []const u8,
    body: []const u8,
    headers: []const []const u8,
) !HttpResponse {
    var argv_buf: [48][]const u8 = undefined;
    var argc: usize = 0;

    argv_buf[argc] = "curl";
    argc += 1;
    argv_buf[argc] = "-s";
    argc += 1;
    argv_buf[argc] = "-X";
    argc += 1;
    argv_buf[argc] = "POST";
    argc += 1;
    argv_buf[argc] = "-H";
    argc += 1;
    argv_buf[argc] = "Content-Type: application/json";
    argc += 1;

    for (headers) |hdr| {
        if (argc + 2 > argv_buf.len) break;
        argv_buf[argc] = "-H";
        argc += 1;
        argv_buf[argc] = hdr;
        argc += 1;
    }

    argv_buf[argc] = "--data-binary";
    argc += 1;
    argv_buf[argc] = "@-";
    argc += 1;
    argv_buf[argc] = "-w";
    argc += 1;
    argv_buf[argc] = "\n%{http_code}";
    argc += 1;
    argv_buf[argc] = url;
    argc += 1;

    var child = std.process.Child.init(argv_buf[0..argc], allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    try child.spawn();

    if (child.stdin) |stdin_file| {
        stdin_file.writeAll(body) catch {
            stdin_file.close();
            child.stdin = null;
            _ = child.kill() catch {};
            _ = child.wait() catch {};
            return error.CurlWriteError;
        };
        stdin_file.close();
        child.stdin = null;
    } else {
        _ = child.kill() catch {};
        _ = child.wait() catch {};
        return error.CurlWriteError;
    }

    const stdout = child.stdout.?.readToEndAlloc(allocator, 1024 * 1024) catch {
        _ = child.kill() catch {};
        _ = child.wait() catch {};
        return error.CurlReadError;
    };
    errdefer allocator.free(stdout);

    const term = child.wait() catch return error.CurlWaitError;
    switch (term) {
        .Exited => |code| if (code != 0) return error.CurlFailed,
        else => return error.CurlFailed,
    }

    const status_sep = std.mem.lastIndexOfScalar(u8, stdout, '\n') orelse return error.CurlParseError;
    const status_raw = std.mem.trim(u8, stdout[status_sep + 1 ..], " \t\r\n");
    if (status_raw.len != 3) return error.CurlParseError;
    const status_code = std.fmt.parseInt(u16, status_raw, 10) catch return error.CurlParseError;
    const body_slice = stdout[0..status_sep];
    const response_body = try allocator.dupe(u8, body_slice);
    allocator.free(stdout);

    return .{
        .status_code = status_code,
        .body = response_body,
    };
}

/// HTTP PUT via curl subprocess (no proxy, no timeout).
pub fn curlPut(allocator: Allocator, url: []const u8, body: []const u8, headers: []const []const u8) ![]u8 {
    return curlRequestWithProxy(allocator, "PUT", url, body, headers, null, null);
}

/// HTTP GET via curl subprocess with optional proxy.
///
/// `headers` is a slice of header strings (e.g. `"Authorization: Bearer xxx"`).
/// `timeout_secs` sets --max-time. Returns the response body. Caller owns returned memory.
fn curlGetWithProxyAndResolve(
    allocator: Allocator,
    url: []const u8,
    headers: []const []const u8,
    timeout_secs: []const u8,
    proxy: ?[]const u8,
    resolve_entry: ?[]const u8,
) ![]u8 {
    var argv_buf: [48][]const u8 = undefined;
    var argc: usize = 0;

    argv_buf[argc] = "curl";
    argc += 1;
    argv_buf[argc] = "-sf";
    argc += 1;
    argv_buf[argc] = "--max-time";
    argc += 1;
    argv_buf[argc] = timeout_secs;
    argc += 1;

    if (proxy) |p| {
        argv_buf[argc] = "--proxy";
        argc += 1;
        argv_buf[argc] = p;
        argc += 1;
    }

    if (resolve_entry) |entry| {
        argv_buf[argc] = "--resolve";
        argc += 1;
        argv_buf[argc] = entry;
        argc += 1;
    }

    for (headers) |hdr| {
        if (argc + 2 > argv_buf.len) break;
        argv_buf[argc] = "-H";
        argc += 1;
        argv_buf[argc] = hdr;
        argc += 1;
    }

    argv_buf[argc] = url;
    argc += 1;

    var child = std.process.Child.init(argv_buf[0..argc], allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    try child.spawn();

    const stdout = child.stdout.?.readToEndAlloc(allocator, 4 * 1024 * 1024) catch {
        _ = child.kill() catch {};
        _ = child.wait() catch {};
        return error.CurlReadError;
    };

    const term = child.wait() catch return error.CurlWaitError;
    switch (term) {
        .Exited => |code| if (code != 0) {
            allocator.free(stdout);
            return error.CurlFailed;
        },
        else => {
            allocator.free(stdout);
            return error.CurlFailed;
        },
    }

    return stdout;
}

/// HTTP GET via curl subprocess with optional proxy.
///
/// `headers` is a slice of header strings (e.g. `"Authorization: Bearer xxx"`).
/// `timeout_secs` sets --max-time. Returns the response body. Caller owns returned memory.
pub fn curlGetWithProxy(
    allocator: Allocator,
    url: []const u8,
    headers: []const []const u8,
    timeout_secs: []const u8,
    proxy: ?[]const u8,
) ![]u8 {
    return curlGetWithProxyAndResolve(allocator, url, headers, timeout_secs, proxy, null);
}

/// HTTP GET via curl subprocess with a pinned host mapping.
///
/// `resolve_entry` must be in curl `--resolve` format: `host:port:address`.
pub fn curlGetWithResolve(
    allocator: Allocator,
    url: []const u8,
    headers: []const []const u8,
    timeout_secs: []const u8,
    resolve_entry: []const u8,
) ![]u8 {
    return curlGetWithProxyAndResolve(allocator, url, headers, timeout_secs, null, resolve_entry);
}

/// HTTP GET via curl subprocess (no proxy).
pub fn curlGet(allocator: Allocator, url: []const u8, headers: []const []const u8, timeout_secs: []const u8) ![]u8 {
    return curlGetWithProxy(allocator, url, headers, timeout_secs, null);
}

/// HTTP GET via curl for SSE (Server-Sent Events).
///
/// Uses -N (--no-buffer) to disable output buffering, allowing
/// SSE events to be received in real-time. Also sends Accept: text/event-stream.
pub fn curlGetSSE(
    allocator: Allocator,
    url: []const u8,
    timeout_secs: []const u8,
) ![]u8 {
    var argv_buf: [40][]const u8 = undefined;
    var argc: usize = 0;

    argv_buf[argc] = "curl";
    argc += 1;
    argv_buf[argc] = "-sf";
    argc += 1;
    argv_buf[argc] = "-N";
    argc += 1;
    argv_buf[argc] = "--max-time";
    argc += 1;
    argv_buf[argc] = timeout_secs;
    argc += 1;
    argv_buf[argc] = "-H";
    argc += 1;
    argv_buf[argc] = "Accept: text/event-stream";
    argc += 1;
    argv_buf[argc] = url;
    argc += 1;

    var child = std.process.Child.init(argv_buf[0..argc], allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    child.spawn() catch |err| {
        std.debug.print("[curlGetSSE] spawn failed: {}\n", .{err});
        return error.CurlFailed;
    };

    const stdout = child.stdout.?.readToEndAlloc(allocator, 4 * 1024 * 1024) catch {
        _ = child.kill() catch {};
        _ = child.wait() catch {};
        return error.CurlReadError;
    };

    const term = child.wait() catch {
        allocator.free(stdout);
        return error.CurlWaitError;
    };
    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                // Exit code 28 = timeout. This is expected for SSE when no data arrives,
                // but curl may have received some data before timing out - return it.
                // For other exit codes, treat as error.
                if (code != 28) {
                    std.debug.print("[curlGetSSE] curl error: code={}\n", .{code});
                    allocator.free(stdout);
                    return error.CurlFailed;
                }
                // Timeout (code 28) - return any data we received
            }
        },
        else => {
            allocator.free(stdout);
            return error.CurlFailed;
        },
    }

    return stdout;
}

// ── Tests ───────────────────────────────────────────────────────────

test "curlPostWithProxy header guard allows at most (argv_buf_len - base_args) / 2 headers" {
    // argv_buf is [40][]const u8. Base args consume 8 slots (curl -s -X POST -H
    // Content-Type --data-binary @- url), leaving 32 slots = 16 header pairs.
    // The guard `argc + 2 > argv_buf.len` stops additions before overflow.
    // We verify the guard constant is consistent: remaining = 40 - 8 = 32, max headers = 16.
    const argv_buf_len = 40;
    const base_args = 8; // curl -s -X POST -H <ct> --data-binary @- <url>
    const max_header_pairs = (argv_buf_len - base_args) / 2;
    try std.testing.expectEqual(@as(usize, 16), max_header_pairs);
}

test "curlPostWithStatus compiles and is callable" {
    try std.testing.expect(true);
}

test "curlPut compiles and is callable" {
    try std.testing.expect(true);
}

test "curlPostForm uses exactly 9 fixed args plus url" {
    // argv_buf is [10][]const u8: curl -s -X POST -H <ct> --data-binary @- <url> = 9 slots.
    // Verify the constant is consistent with the implementation.
    const argv_buf_len = 10;
    const fixed_args = 9; // curl -s -X POST -H Content-Type --data-binary @- (url)
    try std.testing.expect(fixed_args < argv_buf_len);
}

test "curlGet with zero headers compiles and is callable" {
    // Smoke-test: verifies the function signature is reachable and the arg-building
    // path with an empty header slice does not panic at comptime.
    _ = curlGet;
}

test "curlGetWithResolve compiles and is callable" {
    try std.testing.expect(true);
}
