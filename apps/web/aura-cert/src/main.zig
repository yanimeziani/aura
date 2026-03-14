const std = @import("std");

/// A simple ASN.1 DER builder for X.509 certificate generation.
const Der = struct {
    pub fn tag(allocator: std.mem.Allocator, t: u8, data: []const u8) ![]u8 {
        var list = std.ArrayList(u8).empty;
        try list.append(allocator, t);

        const len = data.len;
        if (len < 128) {
            try list.append(allocator, @intCast(len));
        } else {
            var buf: [8]u8 = undefined;
            var i: usize = 0;
            var l = len;
            while (l > 0) {
                buf[i] = @intCast(l & 0xFF);
                l >>= 8;
                i += 1;
            }
            try list.append(allocator, @intCast(0x80 | i));
            while (i > 0) {
                i -= 1;
                try list.append(allocator, buf[i]);
            }
        }
        try list.appendSlice(allocator, data);
        return try list.toOwnedSlice(allocator);
    }

    pub fn seq(allocator: std.mem.Allocator, elements: []const []const u8) ![]u8 {
        var list = std.ArrayList(u8).empty;
        defer list.deinit(allocator);
        for (elements) |el| {
            try list.appendSlice(allocator, el);
        }
        return try tag(allocator, 0x30, list.items);
    }

    pub fn set(allocator: std.mem.Allocator, elements: []const []const u8) ![]u8 {
        var list = std.ArrayList(u8).empty;
        defer list.deinit(allocator);
        for (elements) |el| {
            try list.appendSlice(allocator, el);
        }
        return try tag(allocator, 0x31, list.items);
    }

    pub fn int(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
        return try tag(allocator, 0x02, data);
    }

    pub fn bitString(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
        var list = std.ArrayList(u8).empty;
        defer list.deinit(allocator);
        try list.append(allocator, 0x00); // 0 unused bits
        try list.appendSlice(allocator, data);
        return try tag(allocator, 0x03, list.items);
    }

    pub fn octetString(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
        return try tag(allocator, 0x04, data);
    }

    pub fn oid(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
        return try tag(allocator, 0x06, data);
    }

    pub fn utf8String(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
        return try tag(allocator, 0x0C, data);
    }

    pub fn utcTime(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
        return try tag(allocator, 0x17, data);
    }

    pub fn explicitTag(allocator: std.mem.Allocator, tag_num: u8, data: []const u8) ![]u8 {
        return try tag(allocator, 0xA0 | tag_num, data);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Generating Aura Sovereign Ed25519 SSL Certificate...\n", .{});

    // 1. Generate Ed25519 KeyPair
    const key_pair = std.crypto.sign.Ed25519.KeyPair.generate();

    // 2. Build TBSCertificate
    const version_inner = try Der.int(allocator, &[_]u8{0x02}); // v3
    defer allocator.free(version_inner);
    const version = try Der.explicitTag(allocator, 0, version_inner);
    defer allocator.free(version);

    var serial_bytes: [8]u8 = undefined;
    std.crypto.random.bytes(&serial_bytes);
    serial_bytes[0] &= 0x7F; // ensure positive
    const serial = try Der.int(allocator, &serial_bytes);
    defer allocator.free(serial);

    const ed25519_oid = try Der.oid(allocator, &[_]u8{ 0x2B, 0x65, 0x70 });
    defer allocator.free(ed25519_oid);
    const sig_alg = try Der.seq(allocator, &[_][]const u8{ed25519_oid});
    defer allocator.free(sig_alg);

    const cn_oid = try Der.oid(allocator, &[_]u8{ 0x55, 0x04, 0x03 });
    defer allocator.free(cn_oid);
    const cn_str = try Der.utf8String(allocator, "Aura Sovereign Root");
    defer allocator.free(cn_str);
    const attr = try Der.seq(allocator, &[_][]const u8{ cn_oid, cn_str });
    defer allocator.free(attr);
    const rdn = try Der.set(allocator, &[_][]const u8{attr});
    defer allocator.free(rdn);
    const name = try Der.seq(allocator, &[_][]const u8{rdn});
    defer allocator.free(name);

    const not_before = try Der.utcTime(allocator, "260101000000Z");
    defer allocator.free(not_before);
    const not_after = try Der.utcTime(allocator, "360101000000Z"); // 10 years
    defer allocator.free(not_after);
    const validity = try Der.seq(allocator, &[_][]const u8{ not_before, not_after });
    defer allocator.free(validity);

    const pub_key_bits = try Der.bitString(allocator, &key_pair.public_key.toBytes());
    defer allocator.free(pub_key_bits);
    const spki = try Der.seq(allocator, &[_][]const u8{ sig_alg, pub_key_bits });
    defer allocator.free(spki);

    const tbs = try Der.seq(allocator, &[_][]const u8{
        version, serial, sig_alg, name, validity, name, spki,
    });
    defer allocator.free(tbs);

    // 3. Sign the TBSCertificate
    const signature = try key_pair.sign(tbs, null);
    const sig_bits = try Der.bitString(allocator, &signature.toBytes());
    defer allocator.free(sig_bits);

    // 4. Assemble final Certificate
    const cert = try Der.seq(allocator, &[_][]const u8{
        tbs, sig_alg, sig_bits,
    });
    defer allocator.free(cert);

    // 5. PEM Encode Certificate
    const cert_pem = try pemEncode(allocator, "CERTIFICATE", cert);
    defer allocator.free(cert_pem);

    const cert_file = try std.fs.cwd().createFile("cert.pem", .{});
    defer cert_file.close();
    try cert_file.writeAll(cert_pem);

    // 6. PKCS#8 Private Key
    const priv_version = try Der.int(allocator, &[_]u8{0x00});
    defer allocator.free(priv_version);
    const priv_oct_inner = try Der.octetString(allocator, &key_pair.secret_key.seed());
    defer allocator.free(priv_oct_inner);
    const priv_oct = try Der.octetString(allocator, priv_oct_inner);
    defer allocator.free(priv_oct);
    const pkcs8 = try Der.seq(allocator, &[_][]const u8{
        priv_version, sig_alg, priv_oct,
    });
    defer allocator.free(pkcs8);

    const key_pem = try pemEncode(allocator, "PRIVATE KEY", pkcs8);
    defer allocator.free(key_pem);

    const key_file = try std.fs.cwd().createFile("key.pem", .{});
    defer key_file.close();
    try key_file.writeAll(key_pem);

    std.debug.print("Successfully generated self-signed Ed25519 SSL certificate:\n", .{});
    std.debug.print("  - cert.pem (Sovereign Root CA)\n", .{});
    std.debug.print("  - key.pem  (Private Key)\n", .{});
}

fn pemEncode(allocator: std.mem.Allocator, label: []const u8, data: []const u8) ![]u8 {
    const encoder = std.base64.standard.Encoder;
    const b64_len = encoder.calcSize(data.len);
    const b64 = try allocator.alloc(u8, b64_len);
    defer allocator.free(b64);
    _ = encoder.encode(b64, data);

    var list = std.ArrayList(u8).empty;
    defer list.deinit(allocator);
    try list.writer(allocator).print("-----BEGIN {s}-----\n", .{label});
    var i: usize = 0;
    while (i < b64.len) {
        const end = @min(i + 64, b64.len);
        try list.writer(allocator).print("{s}\n", .{b64[i..end]});
        i += 64;
    }
    try list.writer(allocator).print("-----END {s}-----\n", .{label});
    return try list.toOwnedSlice(allocator);
}
