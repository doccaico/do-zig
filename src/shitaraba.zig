const std = @import("std");
const g = @import("global");
const u = @import("utils");
const c = @import("c");
const mem = std.mem;
const fmt = std.fmt;
const os = std.os;
const unicode = std.unicode;
const process = std.process;
const Io = std.Io;

const HELP_MSG =
    \\USAGE:
    \\    do.exe shitaraba [OPTION] GENRE ID NUMBER
    \\OPTION:
    \\    -h, --help                 ヘルプメッセージを表示
;

fn convert_emoji_with_alloc(allocator: mem.Allocator, subject: []const u8) ![]const u8 {
    var result: std.ArrayList(u8) = .empty;

    var i: usize = 0;
    while (i < subject.len) {
        // 「&#」で始まる数値文字参照を探す
        if (i + 2 < subject.len and subject[i] == '&' and subject[i + 1] == '#') {
            // 末尾の「;」を探す
            if (mem.indexOfScalarPos(u8, subject, i + 2, ';')) |semi_idx| {
                const num_str = subject[i + 2 .. semi_idx];
                // 中身がすべて数字かどうかチェックしてパース
                if (fmt.parseInt(u21, num_str, 10)) |code_point| {
                    // パースに成功したら、コードポイントをUTF-8バイト列に変換
                    var buf: [4]u8 = undefined;
                    const encoded_len: usize = unicode.utf8Encode(code_point, &buf) catch blk: {
                        // 無効なコードポイントの場合は変換せず元のまま通す
                        break :blk 0;
                    };

                    if (encoded_len > 0) {
                        try result.appendSlice(allocator, buf[0..encoded_len]);
                        i = semi_idx + 1; // 「;」の次までインデックスを進める
                        continue;
                    }
                } else |_| {}
            }
        }

        // 通常の文字、またはパースできなかった場合は1バイトそのままコピー
        try result.append(allocator, subject[i]);
        i += 1;
    }

    return result.toOwnedSlice(allocator);
}

pub fn run(args: []const [:0]const u8) !u8 {
    if (args.len == 1 and (mem.eql(u8, args[0], "-h") or mem.eql(u8, args[0], "--help"))) {
        try u.println(HELP_MSG);
        return 0;
    }
    if (args.len != 3) {
        try u.eprintln(HELP_MSG);
        return 1;
    }

    const genre = args[0];
    const id = args[1];
    const number = args[2];

    const url = try fmt.allocPrint(g.allocator, "https://jbbs.shitaraba.net/bbs/read.cgi/{s}/{s}/{s}/l50", .{ genre, id, number });
    const pipe_cmd = try fmt.allocPrint(g.allocator, "curl -sSL -A \"Mozilla/5.0\" {s} | busybox64u iconv -f EUC-JP -t UTF-8", .{url});

    // curlを起動する
    const args_cb = [_][]const u8{ "cmd", "/C", pipe_cmd };
    var child_cb = try process.spawn(g.io, .{
        .argv = &args_cb,
        .stdout = .pipe,
    });

    var stdout_buf: [1024]u8 = undefined;
    const output_cb = blk: {
        if (child_cb.stdout) |stdout| {
            var r = stdout.reader(g.io, &stdout_buf);
            const ret_buf = try r.interface.allocRemaining(g.allocator, .unlimited);
            break :blk ret_buf;
        } else {
            break :blk "";
        }
    };
    const term_cb = try child_cb.wait(g.io);

    if (term_cb.exited != 0) {
        const msg = try fmt.allocPrint(g.allocator, "'curl and busybox64u iconv' failed with exit code '{d}'", .{term_cb.exited});
        try u.eprintln(msg);
        return 1;
    }

    var sb = Io.Writer.Allocating.init(g.allocator);
    const writer = &sb.writer;

    var re: *c.pcre2_code_8 = undefined;
    var match_data: *c.pcre2_match_data_8 = undefined;
    var errornumber: i32 = undefined;
    var erroroffset: c.PCRE2_SIZE = undefined;

    // (?s) DOT-all option
    const pattern =
        \\(?s)<dt.+?<b>(.+?)</b>.+?：(.+?)</dt>.+?<dd>(.+?)<br>          <br>
    ;
    const subject = output_cb;

    // 1. Compile the regular expression
    const maybe_re = c.pcre2_compile_8(pattern.ptr, pattern.len, 0, &errornumber, &erroroffset, null);
    if (maybe_re == null) {
        std.debug.print("Regex's compilation failed\n", .{});
        process.exit(1);
    } else {
        re = maybe_re.?;
    }
    defer c.pcre2_code_free_8(re);

    // 2. Create match data context
    const maybe_match_data = c.pcre2_match_data_create_from_pattern_8(re, null);
    if (maybe_match_data == null) {
        std.debug.print("Create match_data failed\n", .{});
        process.exit(1);
    } else {
        match_data = maybe_match_data.?;
    }
    defer c.pcre2_match_data_free_8(match_data);

    // 検索の開始位置（オフセット）を管理する変数
    var start_offset: c.PCRE2_SIZE = 0;
    var match_count: usize = 1;

    while (true) {
        const rc = c.pcre2_match_8(re, subject.ptr, subject.len, start_offset, 0, match_data, null);

        // マッチしなかった、またはエラーの場合はループを抜ける
        if (rc < 0) {
            if (rc != c.PCRE2_ERROR_NOMATCH) {
                const msg = try fmt.allocPrint(g.allocator, "Matching error: {d}", .{rc});
                try u.eprintln(msg);
                return 1;
            }
            break;
        }

        const ovector = c.pcre2_get_ovector_pointer_8(match_data);

        var loop_arena = std.heap.ArenaAllocator.init(g.allocator);
        defer loop_arena.deinit();
        const loop_allocator = loop_arena.allocator();

        const name = blk: {
            const start = ovector[2];
            const end = ovector[3];
            break :blk try convert_emoji_with_alloc(loop_allocator, subject[start..end]);
        };

        const date = blk: {
            const start = ovector[4];
            const end = ovector[5];
            break :blk mem.trimEnd(u8, subject[start..end], " \n");
        };

        const post = blk: {
            const start = ovector[6];
            const end = ovector[7];
            const trimed_str = mem.trimStart(u8, subject[start..end], " \n");
            const clean_str = try mem.replaceOwned(u8, loop_allocator, trimed_str, "<br>", "");
            break :blk try convert_emoji_with_alloc(loop_allocator, clean_str);
        };

        try writer.print("{s}{s}{s} : {s}{s}{s}\n{s}\n", .{ u.Cyan, name, u.Reset, u.Green, date, u.Reset, post });

        start_offset = ovector[1];
        match_count += 1;
    }

    // 一時ファイルに書き込む
    const tmp_filename = try fmt.allocPrint(g.allocator, "zig_shitaraba_result_{d}.txt", .{os.windows.GetCurrentProcessId()});
    const tmp_file_abs = try u.writeTempFile(tmp_filename, sb.written());

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
