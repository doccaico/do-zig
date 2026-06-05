const std = @import("std");
const g = @import("global");
const u = @import("utils");
const Io = std.Io;
const fmt = std.fmt;
const mem = std.mem;
const process = std.process;

const HELP_MSG =
    \\USAGE:
    \\    do.exe gitup [OPTION] DIR "Up"
    \\    do.exe gitup [OPTION]     "Up"
    \\OPTION:
    \\    -h, --help                 ヘルプメッセージを表示
;

fn execCmd(args: []const []const u8) !u8 {
    var child = try process.spawn(g.io, .{
        .argv = args,
    });

    const term = try child.wait(g.io);

    try g.stdout.flush();
    try g.stderr.flush();

    return term.exited;
}

pub fn run(args: []const [:0]const u8) !u8 {
    if (args.len == 0 or args.len > 2) {
        try u.eprintln(HELP_MSG, .{});
        return 1;
    }
    if (mem.eql(u8, args[0], "-h") or mem.eql(u8, args[0], "--help")) {
        try u.println(HELP_MSG, .{});
        return 0;
    }

    var dir_path: []const u8 = undefined;
    var commit_msg: []const u8 = undefined;

    if (args.len == 2) {
        Io.Dir.accessAbsolute(g.io, args[0], .{}) catch |err| {
            try u.eprintln("failed to Io.Dir.accessAbsolute: '{s}' {any}", .{ args[0], err });
            return 1;
        };
        dir_path = args[0];
        commit_msg = args[1];
    } else {
        dir_path = "";
        commit_msg = args[0];
    }

    if (dir_path.len != 0) {
        var working_dir = try std.Io.Dir.openDirAbsolute(g.io, dir_path, .{});
        defer working_dir.close(g.io);
        try std.process.setCurrentDir(g.io, working_dir);
    }

    // gitを起動する (status --porcelain)
    const args_git_sp = [_][]const u8{ "git", "status", "--porcelain" };
    var child_git_sp = try process.spawn(g.io, .{
        .argv = &args_git_sp,
        .stdout = .pipe,
    });

    var stdout_buf: [1024]u8 = undefined;
    const output_git_sp = blk: {
        if (child_git_sp.stdout) |stdout| {
            var r = stdout.reader(g.io, &stdout_buf);
            const ret_buf = try r.interface.allocRemaining(g.allocator, .unlimited);
            break :blk ret_buf;
        } else {
            break :blk "";
        }
    };
    const term_git_sp = try child_git_sp.wait(g.io);

    if (term_git_sp.exited != 0) {
        try u.eprintln("not a git repository (or git command failed)", .{});
        return 1;
    }

    const clean_output_git_sp = mem.trim(u8, output_git_sp, " \n");
    if (clean_output_git_sp.len == 0) {
        try u.println("There is no need to update", .{});
        return 0;
    }

    // 変更内容を事前に少し表示
    try g.stdout.print("==> Detected changes:\n", .{});
    try g.stdout.print("    {s}\n\n", .{clean_output_git_sp});

    // gitを起動する (add .)
    try g.stdout.print("==> Running: git add .\n", .{});
    if (try execCmd(&[_][]const u8{ "git", "add", "." }) != 0) {
        try u.eprintln("failed to run 'git add'", .{});
        return 1;
    }

    // gitを起動する (commit -m "...")
    try g.stdout.print("==> Running: git commit -m \"{s}\"\n", .{commit_msg});
    if (try execCmd(&[_][]const u8{ "git", "commit", "-m", commit_msg }) != 0) {
        try u.eprintln("failed to run 'git commit'", .{});
        return 1;
    }

    // gitを起動する (push)
    try g.stdout.print("==> Running: git push\n", .{});
    if (try execCmd(&[_][]const u8{ "git", "push" }) != 0) {
        try u.eprintln("failed to run 'git push'", .{});
        return 1;
    }

    try u.println("==> Success! All changes updated and pushed\n", .{});

    return 0;
}
