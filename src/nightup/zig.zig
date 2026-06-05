const std = @import("std");
const c = @import("c");
const g = @import("global");
const u = @import("utils");

const Io = std.Io;
const process = std.process;
const fs = std.fs;

pub fn run(dist_dir: []const u8, download_dir: []const u8) !u8 {
    // 1. 最新バージョンのJSONを取得
    const url = "https://ziglang.org/download/index.json";
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
        try u.eprintln("failed to download index.json", .{});
        return 1;
    }
    try u.println("Download (index.json) is done", .{});

    // 2. PCRE2で master の x86_64-windows 用の URL を抽出
    var re: *c.pcre2_code_8 = undefined;
    var match_data: *c.pcre2_match_data_8 = undefined;
    var errornumber: i32 = undefined;
    var erroroffset: c.PCRE2_SIZE = undefined;

    // (?s) DOTALL オプション
    const pattern =
        \\(?s)"master":\s*\{.*?"x86_64-windows":\s*\{.*?"tarball":\s*"([^"]+)"
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
        try u.eprintln("failed to find ZIP URL for x86_64-windows master", .{});
        return 1;
    }

    const ovector = c.pcre2_get_ovector_pointer_8(match_data);
    // キャプチャグループ1 (URL)
    const download_url = contents[ovector[2]..ovector[3]];
    try u.println("Download URL: {s}", .{download_url});

    // 3. 作業用ディレクトリの作成
    const work_dir_name = "zig-master-upgrade-working";
    const work_dir_path = try fs.path.join(g.allocator, &[_][]const u8{ download_dir, work_dir_name });

    // 既存の作業ディレクトリがあれば削除
    Io.Dir.cwd().deleteTree(g.io, work_dir_path) catch {};

    // 新規作成
    try Io.Dir.cwd().createDirPath(g.io, work_dir_path);
    try u.println("Created working directory: '{s}'", .{work_dir_path});

    // 4. ZIPファイルのダウンロード
    const local_zip = "zig-master-latest.zip";
    const local_zip_path = try fs.path.join(g.allocator, &[_][]const u8{ work_dir_path, local_zip });

    // `curl` を使ってパスを直接指定してファイルをダウンロードする
    const args_zip = [_][]const u8{ "curl", "-fsSL", "-A", "Mozilla/5.0", download_url, "-o", local_zip_path };
    var child_zip = try process.spawn(g.io, .{
        .argv = &args_zip,
    });
    const term_zip = try child_zip.wait(g.io);

    if (term_zip.exited != 0) {
        Io.Dir.cwd().deleteTree(g.io, work_dir_path) catch {};
        try u.eprintln("failed to download ZIP file", .{});
        return 1;
    }
    try u.println("Download (ZIP) is done: {s}", .{local_zip_path});

    // 5. 外部コマンド tar の実行
    // Windowsの `tar` を叩き、作業フォルダに展開させるための引数
    const args_tar = [_][]const u8{ "tar", "-xf", local_zip_path, "-C", work_dir_path, "--strip-components=1" };
    var child_tar = try process.spawn(g.io, .{
        .argv = &args_tar,
    });
    const term_tar = try child_tar.wait(g.io);

    if (term_tar.exited != 0) {
        Io.Dir.cwd().deleteTree(g.io, work_dir_path) catch {};
        try u.eprintln("failed to extract ZIP file with tar", .{});
        return 1;
    }
    try u.println("Extraction is done", .{});

    // 6. 不要になったZIPの削除
    Io.Dir.cwd().deleteFile(g.io, local_zip_path) catch {
        Io.Dir.cwd().deleteTree(g.io, work_dir_path) catch {};
        return 1;
    };
    try u.println("Removed: '{s}'", .{local_zip_path});

    // 7. 配置（アップデートの適用）
    // 既存のインストール先（dist_dir）をツリーごと一発で削除
    Io.Dir.cwd().deleteTree(g.io, dist_dir) catch {
        Io.Dir.cwd().deleteTree(g.io, work_dir_path) catch {};
        return 1;
    };
    try u.println("Removed: '{s}'", .{dist_dir});

    // ワークスペースを作業パスから dist_dir へ移動
    Io.Dir.rename(Io.Dir.cwd(), work_dir_path, Io.Dir.cwd(), dist_dir, g.io) catch {
        Io.Dir.cwd().deleteTree(g.io, work_dir_path) catch {};
        return 1;
    };

    try u.println("Moved: '{s}' to '{s}'", .{ work_dir_path, dist_dir });
    try u.println("Updated: '{s}'", .{dist_dir});

    return 0;
}
