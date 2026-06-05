const std = @import("std");
const g = @import("global");
const u = @import("utils");
const Io = std.Io;
const fmt = std.fmt;
const fs = std.fs;
const mem = std.mem;
const process = std.process;

// 各言語のアップデーターモジュール（プロジェクトの構成に合わせてインポート）
// const golang = @import("nightup/golang");
// const vim = @import("nightup/vim");
// const vlang = @import("nightup/vlang");
const zig = @import("zig");
const odin = @import("odin");
const v = @import("v");

const HELP_MSG =
    \\Usage:
    \\    do.exe nightup go
    \\    do.exe nightup odin
    \\    do.exe nightup v
    \\    do.exe nightup zig
    \\    do.exe nightup vim
;

pub fn run(args: []const [:0]const u8) !u8 {
    if (args.len == 1 and (mem.eql(u8, args[0], "-h") or mem.eql(u8, args[0], "--help"))) {
        try u.println(HELP_MSG, .{});
        return 0;
    }
    if (args.len != 1) {
        try u.eprintln(HELP_MSG, .{});
        return 1;
    }

    const target = args[0];

    // 1. ホームディレクトリの取得と .nightup パスの結合
    // ※ Zig 0.16.0 では os.getenv("USERPROFILE") もしくは std.process.getEnvVarOwned を利用します
    const home_dir = g.environ_map.get("USERPROFILE") orelse {
        try u.eprintln("Impossible to get your home dir (USERPROFILE)!", .{});
        return 1;
    };

    const ini_path = try fs.path.join(g.allocator, &[_][]const u8{ home_dir, ".nightup" });

    // 2. INIファイルのロードとパース
    const ini_file = Io.Dir.openFileAbsolute(g.io, ini_path, .{}) catch {
        try u.eprintln("failed to open: {s}", .{ini_path});
        return 1;
    };
    defer ini_file.close(g.io);

    // ファイル全体を読み込む
    var file_buf: [1024]u8 = undefined;
    var r = ini_file.reader(g.io, file_buf[0..]);
    const ini_content = try r.interface.allocRemaining(g.allocator, .unlimited);

    // INIファイルのパース処理 (Windowsセクション下のキーを抽出)
    var dist_dir: ?[]const u8 = null;
    var in_windows_section = false;

    var lines = mem.tokenizeScalar(u8, ini_content, '\n');
    while (lines.next()) |raw_line| {
        const line = mem.trim(u8, raw_line, " \r\t");
        if (line.len == 0 or line[0] == ';') continue;

        // セクションのチェック
        if (line[0] == '[' and line[line.len - 1] == ']') {
            const section_name = line[1 .. line.len - 1];
            in_windows_section = mem.eql(u8, section_name, "Windows");
            continue;
        }

        // [Windows] セクション内かつ、対象ターゲットのキーを探す
        if (in_windows_section) {
            var kv_split = mem.splitScalar(u8, line, '=');
            const key = mem.trim(u8, kv_split.next() orelse "", " \t");
            if (mem.eql(u8, key, target)) {
                const val = mem.trim(u8, kv_split.rest(), " \t");
                dist_dir = val;
                break;
            }
        }
    }

    // "vim" 以外は、INIファイルからパスが引けないとエラーにする
    if (dist_dir == null and !mem.eql(u8, target, "vim")) {
        // セクション自体が無かったか、キーが無かったかの簡易判定メッセージ
        try u.eprintln("nightup ini: not found path or section for \"{s}\"", .{target});
        return 1;
    }

    // if (!mem.eql(u8, target, "vim")) {
    //     std.debug.print("{s}\n", .{dist_dir.?});
    // }

    // 4. 一時保存ディレクトリの設定 (TEMP環境変数から取得)
    const download_dir = g.environ_map.get("TEMP") orelse ".";

    // 5. 各言語のアップデート処理への振り分け
    var exit_code: u8 = 0;
    if (mem.eql(u8, target, "zig")) {
        exit_code = try zig.run(dist_dir.?, download_dir);
    } else if (mem.eql(u8, target, "odin")) {
        exit_code = try odin.run(dist_dir.?, download_dir);
    } else if (mem.eql(u8, target, "v")) {
        exit_code = try v.run(dist_dir.?, download_dir);
        // } else if (mem.eql(u8, target, "go")) {
        //     try go.run(dist_dir.?, download_dir);
        // } else if (mem.eql(u8, target, "vim")) {
        //     try vim.run();
    } else {
        try u.eprintln("nightup: unknown command '{s}'", .{target});
        try u.eprintln(HELP_MSG, .{});
        exit_code = 1;
    }

    return exit_code;
}
