const std = @import("std");
const c = @import("c");
const g = @import("global");
const u = @import("utils");
const Io = std.Io;
const fmt = std.fmt;
const mem = std.mem;
const os = std.os;
const process = std.process;

const HELP_MSG =
    \\USAGE:
    \\    do.exe verse [OPTION] 書物 章
    \\OPTION:
    \\    -h, --help                 ヘルプメッセージを表示
    \\
    \\      - 旧約 (Old Testament) -
    \\
    \\      創世記:GEN(1:50)
    \\      出エジプト記:EXO(1:40)
    \\      レビ記:LEV(1:27)
    \\      民数記:NUM(1:36)
    \\      申命記:DEU(1:34)
    \\      ヨシュア記:JOS(1:24)
    \\      士師記:JDG(1:21)
    \\      ルツ記:RUT(1:4)
    \\      サムエル記(上):1SA(1:31)
    \\      サムエル記(下):2SA(1:24)
    \\      列王記(上):1KI(1:22)
    \\      列王記(下):2KI(1:25)
    \\      歴代誌(上):1CH(1:29)
    \\      歴代誌(下):2CH(1:36)
    \\      エズラ記:EZR(1:10)
    \\      ネヘミヤ記:NEH(1:13)
    \\      エステル記:EST(1:10)
    \\      ヨブ記:JOB(1:42)
    \\      詩編:PSA(1:150)
    \\      箴言:PRO(1:31)
    \\      コヘレトの言葉:ECC(1:12)
    \\      雅歌:SNG(1:8)
    \\      イザヤ書:ISA(1:66)
    \\      エレミヤ書:JER(1:52)
    \\      哀歌:LAM(1:5)
    \\      エゼキエル書:EZK(1:48)
    \\      ダニエル書:DAN(1:12)
    \\      ホセア書:HOS(1:14)
    \\      ヨエル書:JOL(1:4)
    \\      アモス書:AMO(1:9)
    \\      オバデヤ書:OBA(1)
    \\      ヨナ書:JON(1:4)
    \\      ミカ書:MIC(1:7)
    \\      ナホム書:NAM(1:3)
    \\      ハバクク書:HAB(1:3)
    \\      ゼファニヤ書:ZEP(1:3)
    \\      ハガイ書:HAG(1:2)
    \\      ゼカリヤ書:ZEC(1:14)
    \\      マラキ書:MAL(1:3)
    \\      ユディト記:JDT(1:16)
    \\      知恵の書:WIS(1:19)
    \\      トビト記:TOB(1:14)
    \\      シラ:SIR(1:51)
    \\      バルク書:BAR(1:5)
    \\      エレミヤの手紙:LJE(1)
    \\      マカバイ記(一):1MA(1:16)
    \\      マカバイ記(二 書簡):2MA(1:15)
    \\      エステル記(ギリシア語):ESG(1:10 + 10_1)
    \\      ダニエル書補遺 スザンナ:SUS(1)
    \\      ダニエル書補遺 ベルと竜:BEL(1)
    \\      ダニエル書補遺 アザルヤの祈りと三人の若者の賛歌:S3Y(1)
    \\      エズラ記(ギリシア語):1ES(1:9)
    \\      エズラ記(ラテン語):2ES(1:16)
    \\      マナセの祈り:MAN(1)
    \\
    \\      - 新約 (New Testament) -
    \\
    \\      マタイによる福音書:MAT(1:28)
    \\      マルコによる福音書:MRK(1:16)
    \\      ルカによる福音書:LUK(1:24)
    \\      ヨハネによる福音書:JHN(1:21)
    \\      使徒言行録:ACT(1:28)
    \\      ローマの信徒への手紙:ROM(1:16)
    \\      コリントの信徒への手紙(一):1CO(1:16)
    \\      コリントの信徒への手紙(二):2CO(1:13)
    \\      ガラテヤの信徒への手紙:GAL(1:6)
    \\      エフェソの信徒への手紙:EPH(1:6)
    \\      フィリピの信徒への手紙:PHP(1:4)
    \\      コロサイの信徒への手紙:COL(1:4)
    \\      テサロニケの信徒への手紙(一):1TH(1:5)
    \\      テサロニケの信徒への手紙(二):2TH(1:3)
    \\      テモテへの手紙(一):1TI(1:6)
    \\      テモテへの手紙(二):2TI(1:4)
    \\      テトスへの手紙:TIT(1:3)
    \\      フィレモンへの手紙:PHM(1)
    \\      ペトロの手紙(一):1PE(1:5)
    \\      ペトロの手紙(二):2PE(1:3)
    \\      ヨハネの手紙(一):1JN(1:5)
    \\      ヨハネの手紙(二):2JN(1)
    \\      ヨハネの手紙(三):3JN(1)
    \\      ヘブライ人への手紙:HEB(1:13)
    \\      ヤコブの手紙:JAS(1:5)
    \\      ユダの手紙:JUD(1)
    \\      ヨハネの黙示録:REV(1:22)
;

pub fn run(args: []const [:0]const u8) !u8 {
    if (args.len == 1 and (mem.eql(u8, args[0], "-h") or mem.eql(u8, args[0], "--help"))) {
        try u.println(HELP_MSG, .{});
        return 0;
    }
    if (args.len != 2) {
        try u.eprintln(HELP_MSG, .{});
        return 1;
    }

    const book = args[0];
    const chapter = args[1];

    const url = try fmt.allocPrint(g.allocator, "https://bible.com/ja/bible/1819/{s}.{s}/", .{ book, chapter });

    // curlを起動する
    const args_curl = [_][]const u8{ "curl", "-sSL", "-A", "Mozilla/5.0", url };
    var child_curl = try process.spawn(g.io, .{
        .argv = &args_curl,
        .stdout = .pipe,
    });

    var stdout_buf: [1024]u8 = undefined;
    const output_curl = blk: {
        if (child_curl.stdout) |stdout| {
            var r = stdout.reader(g.io, &stdout_buf);
            const ret_buf = try r.interface.allocRemaining(g.allocator, .unlimited);
            break :blk ret_buf;
        } else {
            break :blk "";
        }
    };
    const term_curl = try child_curl.wait(g.io);

    if (term_curl.exited != 0) {
        try u.eprintln("'curl' failed with exit code '{d}'", .{term_curl.exited});
        return 1;
    }

    var sb_body = Io.Writer.Allocating.init(g.allocator);
    const writer_body = &sb_body.writer;

    var re: *c.pcre2_code_8 = undefined;
    var match_data: *c.pcre2_match_data_8 = undefined;
    var errornumber: i32 = undefined;
    var erroroffset: c.PCRE2_SIZE = undefined;

    // (?s) DOT-all option
    const pattern =
        \\(?s)(?s)content">(.+?)</span>
    ;
    const subject = output_curl;

    // 1. Compile the regular expression
    const maybe_re = c.pcre2_compile_8(pattern.ptr, pattern.len, 0, &errornumber, &erroroffset, null);
    if (maybe_re == null) {
        try u.eprintln("Regex's compilation failed", .{});
        return 1;
    } else {
        re = maybe_re.?;
    }
    defer c.pcre2_code_free_8(re);

    // 2. Create match data context
    const maybe_match_data = c.pcre2_match_data_create_from_pattern_8(re, null);
    if (maybe_match_data == null) {
        try u.eprintln("Create match_data failed", .{});
        return 1;
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
                try u.eprintln("Matching error: {d}", .{rc});
                return 1;
            }
            break;
        }

        const ovector = c.pcre2_get_ovector_pointer_8(match_data);

        const body = blk: {
            const start = ovector[2];
            const end = ovector[3];
            break :blk mem.trim(u8, subject[start..end], " \n");
        };

        if (body.len != 0) try writer_body.print("{s}\n", .{body});

        start_offset = ovector[1];
        match_count += 1;
    }

    if (sb_body.written().len == 0) {
        try g.stderr.writeAll("no verses found or failed to parse the page\n");
        try g.stderr.print("check the page: {s}\n", .{url});
        return 1;
    }

    var sb = Io.Writer.Allocating.init(g.allocator);
    const writer = &sb.writer;

    // merge
    try writer.print("{s}{s}{s}({s}{s}{s})\n", .{ u.Cyan, book, u.Reset, u.Green, chapter, u.Reset });
    try writer.writeAll(sb_body.written());

    // 一時ファイルに書き込む
    const tmp_filename = try fmt.allocPrint(g.allocator, "zig_verse_result_{d}.txt", .{os.windows.GetCurrentProcessId()});
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
        try u.eprintln("'less' failed with exit code '{d}'", .{term_less.exited});
        return 1;
    }

    return 0;
}
