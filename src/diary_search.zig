const std = @import("std");
const g = @import("global");
const u = @import("utils");
const mem = std.mem;
const fmt = std.fmt;
const os = std.os;
const process = std.process;
const Io = std.Io;

const HELP_MSG =
    \\USAGE:
    \\    do.exe diary_search [OPTION] 検索キーワード
    \\OPTION:
    \\    -h, --help                 ヘルプメッセージを表示
    \\REQUIRED:
    \\    環境変数(DIARY_DIR)に日記が入っているディレクトリを設定すること"""
;

pub fn run(args: []const [:0]const u8) !u8 {
    if (args.len == 1 and (mem.eql(u8, args[0], "-h") or mem.eql(u8, args[0], "--help"))) {
        try u.println(HELP_MSG);
        return 0;
    }
    if (args.len != 1) {
        try u.eprintln(HELP_MSG);
        return 1;
    }

    const diary_dir = blk: {
        var path: []const u8 = undefined;
        if (g.environ_map.get("DIARY_DIR")) |raw_path| {
            try Io.Dir.accessAbsolute(g.io, raw_path, .{});
            path = raw_path;
        } else {
            try u.eprintln("not found 'DIARY_DIR' in env variable");
            return 1;
        }
        break :blk path;
    };

    const keyword = args[0];

    // rgを起動する
    const args_rg = [_][]const u8{ "rg", "--color=always", "--heading", "--line-number", "--ignore-case", "--sort=path", keyword, diary_dir };
    var child_rg = try process.spawn(g.io, .{
        .argv = &args_rg,
        .stdout = .pipe,
    });

    var stdout_buf: [1024]u8 = undefined;
    const output_rg = blk: {
        if (child_rg.stdout) |stdout| {
            var r = stdout.reader(g.io, &stdout_buf);
            const ret_buf = try r.interface.allocRemaining(g.allocator, .unlimited);
            break :blk ret_buf;
        } else {
            break :blk "";
        }
    };
    const term_rg = try child_rg.wait(g.io);

    if (term_rg.exited != 0) {
        if (term_rg.exited == 1) {
            const msg = try fmt.allocPrint(g.allocator, "No matches found for '{s}'", .{keyword});
            try u.println(msg);
            return 0;
        } else {
            const msg = try fmt.allocPrint(g.allocator, "'rg' failed with exit code '{d}'", .{term_rg.exited});
            try u.eprintln(msg);
            return 1;
        }
    }

    // 一時ファイルに書き込む
    const tmp_filename = try fmt.allocPrint(g.allocator, "zig_diary_search_result_{d}.txt", .{os.windows.GetCurrentProcessId()});
    const tmp_file_abs = try u.writeTempFile(tmp_filename, output_rg);

    // lessを起動する
    const args_less = [_][]const u8{ "less", "-R", "-i", "--silent", tmp_file_abs };
    var child_less = try process.spawn(g.io, .{
        .argv = &args_less,
    });
    const term_less = try child_less.wait(g.io);

    // 一時ファイルを削除する
    try Io.Dir.deleteFileAbsolute(g.io, tmp_file_abs);

    if (term_less.exited != 0) {
        const msg = try fmt.allocPrint(g.allocator, "'less' failed with exit code '{d}'", .{term_less.exited});
        try u.eprintln(msg);
        return 1;
    }

    return 0;
}
