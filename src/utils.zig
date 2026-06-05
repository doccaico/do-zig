const std = @import("std");
const g = @import("global");
const c = @import("c");
const Io = std.Io;

pub const Reset = "\x1b[0m";
pub const Red = "\x1b[31m";
pub const Green = "\x1b[32m";
pub const Yellow = "\x1b[33m";
pub const Blue = "\x1b[34m";
pub const Magenta = "\x1b[35m";
pub const Cyan = "\x1b[36m";
pub const White = "\x1b[37m";

// pub const PCRE2_ZERO_TERMINATED = ~@as(c.PCRE2_SIZE, 0);

pub fn println(comptime fmt: []const u8, args: anytype) !void {
    try g.stdout.print(fmt, args);
    try g.stdout.writeByte('\n');
    try g.stdout.flush();
}

pub fn eprintln(comptime fmt: []const u8, args: anytype) !void {
    try g.stderr.print(fmt, args);
    try g.stderr.writeByte('\n');
    try g.stderr.flush();
}

// pub fn println(msg: []const u8) !void {
//     try g.stdout.print("{s}\n", .{msg});
// }
//
// pub fn eprintln(msg: []const u8) !void {
//     try g.stderr.print("{s}\n", .{msg});
// }

pub fn writeTempFile(filename: []const u8, contents: []const u8) ![]const u8 {
    var path: []const u8 = undefined;
    if (g.environ_map.get("TEMP")) |raw_path| {
        path = raw_path;
    } else {
        try eprintln("not found 'TEMP' in env variable", .{});
        return error.EnvTempNotFound;
    }

    var dir = try Io.Dir.openDirAbsolute(g.io, path, .{});
    defer dir.close(g.io);

    const file = try dir.createFile(g.io, filename, .{
        .truncate = true,
    });
    defer file.close(g.io);

    var fwriter = file.writer(g.io, &.{});
    try fwriter.interface.writeAll(contents);
    return try std.fs.path.join(g.allocator, &.{ path, filename });
}
