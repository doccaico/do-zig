const std = @import("std");
const c = @import("c");
const g = @import("global");
const u = @import("utils");

const Io = std.Io;
const fmt = std.fmt;
const fs = std.fs;
const process = std.process;

pub fn run() !u8 {
    // 1. 最新リリースのJSONを取得
    const url = "https://api.github.com/repos/vim/vim-win32-installer/releases/latest";
    const args_curl = [_][]const u8{ "curl", "-sSL", "-A", "Mozilla/5.0", url };
    var child_curl = try process.spawn(g.io, .{
        .argv = &args_curl,
        .stdout = .pipe,
    });

    var curl_buf: [1024]u8 = undefined;
    const contents = blk: {
        if (child_curl.stdout) |stdout| {
            var r = stdout.reader(g.io, curl_buf[0..]);
            break :blk try r.interface.allocRemaining(g.allocator, .unlimited);
        } else {
            break :blk "";
        }
    };
    const term_curl = try child_curl.wait(g.io);

    if (term_curl.exited != 0 or contents.len == 0) {
        try u.eprintln("failed to download json", .{});
        return 1;
    }
    try u.println("Download (json) is done", .{});

    // 2. 正規表現でインストーラー（.exe）のダウンロードURLを抽出
    var re: *c.pcre2_code_8 = undefined;
    var match_data: *c.pcre2_match_data_8 = undefined;
    var errornumber: i32 = undefined;
    var erroroffset: c.PCRE2_SIZE = undefined;

    const pattern =
        \\browser_download_url":\s*"(https://[^"]+_x64_signed\.exe)
    ;
    const maybe_re = c.pcre2_compile_8(pattern.ptr, pattern.len, 0, &errornumber, &erroroffset, null);
    if (maybe_re == null) {
        try u.eprintln("Regex's compilation failed", .{});
        return 1;
    }
    re = maybe_re.?;
    defer c.pcre2_code_free_8(re);

    const maybe_match_data = c.pcre2_match_data_create_from_pattern_8(re, null);
    if (maybe_match_data == null) {
        try u.eprintln("Create match_data failed", .{});
        return 1;
    }
    match_data = maybe_match_data.?;
    defer c.pcre2_match_data_free_8(match_data);

    const rc = c.pcre2_match_8(re, contents.ptr, contents.len, 0, 0, match_data, null);
    if (rc < 0) {
        try u.eprintln("failed to find ZIP URL for gvim-x64-signed", .{});
        return 1;
    }

    const ovector = c.pcre2_get_ovector_pointer_8(match_data);
    // キャプチャグループ1 (_x64_signed.exe のURL部分)
    const download_url = contents[ovector[2]..ovector[3]];
    try u.println("Download URL: {s}", .{download_url});

    // 3. ユーザーの「ダウンロード」フォルダパスを構築 ($HOME/Downloads)
    const home_dir = g.environ_map.get("USERPROFILE") orelse {
        try u.eprintln("Impossible to get your home dir (USERPROFILE)!", .{});
        return 1;
    };
    const user_download_dir = try fs.path.join(g.allocator, &[_][]const u8{ home_dir, "Downloads" });

    // 4. curl を使ってインストーラーをダウンロード
    // -fsSOL オプションは、URLの末尾のファイル名を使ってカレントディレクトリに保存する引数
    // `curl` の実行ディレクトリを指定する代わりに、引数にディレクトリを含めるか、cmd経由でcdさせて実行する
    const cmd_curl_exe = try fmt.allocPrint(g.allocator,
        \\cd /d {s} && curl -fsSOL -A "Mozilla/5.0" {s}
    , .{ user_download_dir, download_url });
    const args_exe = [_][]const u8{ "cmd", "/c", cmd_curl_exe };
    var child_exe = try process.spawn(g.io, .{
        .argv = &args_exe,
    });
    const term_exe = try child_exe.wait(g.io);

    if (term_exe.exited != 0) {
        try u.eprintln("failed to download EXE", .{});
        return 1;
    }
    try u.println("Download (ZIP) is done", .{});

    // 5. 外部コマンド cmd /C start explorer . の実行
    // ダウンロードフォルダを基点にしてエクスプローラーを開く
    const cmd_explorer = try fmt.allocPrint(g.allocator,
        \\cd /d {s} && cmd /C start explorer .
    , .{user_download_dir});
    const args_explorer = [_][]const u8{ "cmd", "/c", cmd_explorer };
    var child_explorer = try process.spawn(g.io, .{
        .argv = &args_explorer,
    });
    const term_explorer = try child_explorer.wait(g.io);

    if (term_explorer.exited != 0) {
        try u.eprintln("failed to open explorer", .{});
        return 1;
    }
    try u.println("Opened EXPLORER.EXE", .{});

    return 0;
}
