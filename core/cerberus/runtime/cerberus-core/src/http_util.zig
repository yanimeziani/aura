const std = @import("std");
const Allocator = std.mem.Allocator;
const ca_store = @import("security/ca_store.zig");

const log = std.log.scoped(.http_util);

pub const HttpResponse = struct {
    status_code: u16,
    body: []u8,
};

fn curlRequestWithProxyDetailed(
    allocator: Allocator,
    method: []const u8,
    url: []const u8,
    body: []const u8,
    headers: []const []const u8,
    proxy: ?[]const u8,
    max_time: ?[]const u8,
    resolve: ?[]const u8,
) !HttpResponse {
    var argv_buf: [50][]const u8 = undefined;
    var argc: usize = 0;
    argv_buf[argc] = "curl"; argc += 1;
    argv_buf[argc] = "-s"; argc += 1;
    argv_buf[argc] = "-w"; argc += 1;
    argv_buf[argc] = "%{http_code}"; argc += 1;
    argv_buf[argc] = "-X"; argc += 1;
    argv_buf[argc] = method; argc += 1;

    if (ca_store.findSystemCaPath()) |path| {
        argv_buf[argc] = "--cacert"; argc += 1;
        argv_buf[argc] = path; argc += 1;
    }

    if (proxy) |p| {
        argv_buf[argc] = "--proxy"; argc += 1;
        argv_buf[argc] = p; argc += 1;
    }

    if (max_time) |mt| {
        argv_buf[argc] = "--max-time"; argc += 1;
        argv_buf[argc] = mt; argc += 1;
    }

    if (resolve) |r| {
        argv_buf[argc] = "--resolve"; argc += 1;
        argv_buf[argc] = r; argc += 1;
    }

    for (headers) |hdr| {
        argv_buf[argc] = "-H"; argc += 1;
        argv_buf[argc] = hdr; argc += 1;
    }

    if (body.len > 0) {
        argv_buf[argc] = "--data-binary"; argc += 1;
        argv_buf[argc] = "@-"; argc += 1;
    }

    argv_buf[argc] = url; argc += 1;

    var child = std.process.Child.init(argv_buf[0..argc], allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    try child.spawn();

    if (body.len > 0) {
        try child.stdin.?.writeAll(body);
        child.stdin.?.close();
    }

    const output = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024 * 20);
    _ = try child.wait();

    if (output.len < 3) return error.CurlOutputTooShort;
    const status_str = output[output.len-3..output.len];
    const status_code = try std.fmt.parseInt(u16, status_str, 10);
    const actual_body = try allocator.dupe(u8, output[0..output.len-3]);
    allocator.free(output);

    return HttpResponse{ .status_code = status_code, .body = actual_body };
}

pub fn curlGet(allocator: Allocator, url: []const u8, headers: []const []const u8, max_time: ?[]const u8) ![]u8 {
    const resp = try curlRequestWithProxyDetailed(allocator, "GET", url, "", headers, null, max_time, null);
    return resp.body;
}

pub fn curlPost(allocator: Allocator, url: []const u8, body: []const u8, headers: []const []const u8) ![]u8 {
    const resp = try curlRequestWithProxyDetailed(allocator, "POST", url, body, headers, null, null, null);
    return resp.body;
}

pub fn curlPostWithProxy(allocator: Allocator, url: []const u8, body: []const u8, hdrs: []const []const u8, proxy: ?[]const u8, max_time: ?[]const u8) ![]u8 {
    const resp = try curlRequestWithProxyDetailed(allocator, "POST", url, body, hdrs, proxy, max_time, null);
    return resp.body;
}

pub fn curlPut(allocator: Allocator, url: []const u8, body: []const u8, hdrs: []const []const u8) ![]u8 {
    const resp = try curlRequestWithProxyDetailed(allocator, "PUT", url, body, hdrs, null, null, null);
    return resp.body;
}

pub fn curlPostWithStatus(allocator: Allocator, url: []const u8, body: []const u8, hdrs: []const []const u8) !HttpResponse {
    return curlRequestWithProxyDetailed(allocator, "POST", url, body, hdrs, null, null, null);
}

pub fn curlGetWithProxy(allocator: Allocator, url: []const u8, hdrs: []const []const u8, max_time: ?[]const u8, proxy: ?[]const u8) ![]u8 {
    const resp = try curlRequestWithProxyDetailed(allocator, "GET", url, "", hdrs, proxy, max_time, null);
    return resp.body;
}

pub fn curlGetWithResolve(allocator: Allocator, url: []const u8, hdrs: []const []const u8, max_time: ?[]const u8, resolve: []const u8) ![]u8 {
    const resp = try curlRequestWithProxyDetailed(allocator, "GET", url, "", hdrs, null, max_time, resolve);
    return resp.body;
}

pub fn curlPostForm(allocator: Allocator, url: []const u8, body: []const u8) ![]u8 {
    const resp = try curlRequestWithProxyDetailed(allocator, "POST", url, body, &.{}, null, null, null);
    return resp.body;
}
