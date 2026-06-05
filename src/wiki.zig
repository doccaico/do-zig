const std = @import("std");
const g = @import("global");
const u = @import("utils");
const Io = std.Io;
const fmt = std.fmt;
const json = std.json;
const mem = std.mem;
const os = std.os;
const process = std.process;

const HELP_MSG =
    \\USAGE:
    \\    do.exe wiki [OPTION] COUNT
    \\OPTION:
    \\    -h, --help                 ヘルプメッセージを表示
;

const WikiResponse = struct {
    query: struct {
        random: []struct {
            id: i64,
            ns: i64,
            title: []const u8,
        },
    },
};

pub fn run(args: []const [:0]const u8) !u8 {
    if (args.len == 1 and (mem.eql(u8, args[0], "-h") or mem.eql(u8, args[0], "--help"))) {
        try u.println(HELP_MSG, .{});
        return 0;
    }
    if (args.len != 1) {
        try u.eprintln(HELP_MSG, .{});
        return 1;
    }

    const count = args[0];

    const url = try fmt.allocPrint(g.allocator, "https://ja.wikipedia.org/w/api.php" ++
        "?format=json" ++
        "&action=query" ++
        "&list=random" ++
        "&rnnamespace=0" ++
        "&rnfilterredir=nonredirects" ++
        "&rnlimit={s}", .{count});

    // curlを起動する
    const args_curl = [_][]const u8{ "curl", "-sSL", "-A", "Mozilla/5.0", url };
    var child_curl = try process.spawn(g.io, .{
        .argv = &args_curl,
        .stdout = .pipe,
    });

    var stdout_buf: [1024]u8 = undefined;
    const json_content = blk: {
        if (child_curl.stdout) |stdout| {
            var r = stdout.reader(g.io, stdout_buf[0..]);
            break :blk try r.interface.allocRemaining(g.allocator, .unlimited);
        } else {
            break :blk "";
        }
    };
    const term_curl = try child_curl.wait(g.io);

    if (term_curl.exited != 0 or json_content.len == 0) {
        try u.eprintln("failed to fetch Wikipedia JSON", .{});
        return 1;
    }

    const parsed = json.parseFromSlice(WikiResponse, g.allocator, json_content, .{
        .ignore_unknown_fields = true,
    }) catch {
        try u.eprintln("failed to parse JSON structure", .{});
        return 1;
    };

    // 一時ファイル書き込み用のバッファ
    var sb = Io.Writer.Allocating.init(g.allocator);
    const writer = &sb.writer;

    // パースされた配列をループ処理
    for (parsed.value.query.random, 1..) |item, index| {
        try writer.print("{s}{d}{s}:{s}{s}{s}:{s}https://ja.wikipedia.org/?curid={d}{s}\n", .{
            u.Magenta, index,      u.Reset,
            u.Cyan,    item.title, u.Reset,
            u.Green,   item.id,    u.Reset,
        });
    }

    if (sb.written().len == 0) {
        try u.eprintln("no articles found", .{});
        return 1;
    }

    // 一時ファイルに書き込む
    const tmp_filename = try fmt.allocPrint(g.allocator, "zig_wiki_result_{d}.txt", .{os.windows.GetCurrentProcessId()});
    const tmp_file_abs = try u.writeTempFile(tmp_filename, sb.written());

    // lessを起動する
    const args_less = [_][]const u8{ "less", "-R", "--silent", tmp_file_abs };
    var child_less = try process.spawn(g.io, .{
        .argv = &args_less,
    });
    const term_less = try child_less.wait(g.io);

    // 一時ファイルを削除する
    try Io.Dir.deleteFileAbsolute(g.io, tmp_file_abs);

    if (term_less.exited != 0) {
        try u.eprintln("'less' failed with exit code '{d}'", .{term_less.exited});
        return 1;
    }

    return 0;
}
