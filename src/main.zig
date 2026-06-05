const std = @import("std");
const builtin = @import("builtin");
const g = @import("global");
const u = @import("utils");
const diary_search = @import("diary_search");
const shitaraba = @import("shitaraba");
const gitup = @import("gitup");
const delete_duplicate_path = @import("delete_duplicate_path");
const verse = @import("verse");
const wiki = @import("wiki");
const process = std.process;
const mem = std.mem;
const os = std.os;
const Io = std.Io;

pub extern "kernel32" fn SetConsoleOutputCP(
    wCodePageID: os.windows.UINT,
) callconv(.winapi) os.windows.BOOL;

const HELP_MSG =
    \\USAGE:
    \\    do.exe [OPTION] COMMAND
    \\OPTION:
    \\    -h, --help                  ヘルプメッセージを表示
    \\COMMAND:
    \\    diary_search                日記を検索
    \\    gitup                       GithubにPush
    \\    shitaraba                   Shitarabaを閲覧
    \\    delete_duplicate_path       環境変数PATHの重複を解消して表示
    \\    verse                       聖書(新共同訳)を表示
    \\    wiki                        ランダムWIKIのリストを表示
    \\    nightup                     ソフトウェアアップデーター
;

pub fn main(init: process.Init) !void {
    if (builtin.os.tag == .windows) {
        _ = SetConsoleOutputCP(65001);
    }

    g.allocator = init.arena.allocator();
    g.environ_map = init.environ_map;
    g.io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), g.io, &stdout_buffer);
    g.stdout = &stdout_file_writer.interface;

    var stderr_buffer: [1024]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), g.io, &stderr_buffer);
    g.stderr = &stderr_file_writer.interface;

    const args = try init.minimal.args.toSlice(g.allocator);

    if (args.len == 1) {
        try u.eprintln(HELP_MSG);
        process.exit(1);
    }
    if (mem.eql(u8, args[1], "-h") or mem.eql(u8, args[1], "--help")) {
        try u.println(HELP_MSG);
        process.exit(0);
    }

    const command = args[1];

    var exit_code: u8 = 0;
    if (mem.eql(u8, command, "diary_search")) {
        exit_code = try diary_search.run(args[2..]);
    } else if (mem.eql(u8, command, "shitaraba")) {
        exit_code = try shitaraba.run(args[2..]);
    } else if (mem.eql(u8, command, "gitup")) {
        exit_code = try gitup.run(args[2..]);
    } else if (mem.eql(u8, command, "delete_duplicate_path")) {
        exit_code = try delete_duplicate_path.run();
    } else if (mem.eql(u8, command, "verse")) {
        exit_code = try verse.run(args[2..]);
    } else if (mem.eql(u8, command, "wiki")) {
        exit_code = try wiki.run(args[2..]);
    } else {
        try g.stderr.print("unknown command '{s}'\n", .{command});
        try u.eprintln(HELP_MSG);
        exit_code = 1;
    }

    try g.stdout.flush();
    try g.stderr.flush();

    process.exit(exit_code);
}
