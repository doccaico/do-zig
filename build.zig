const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pcre2_dep = b.dependency("pcre2", .{
        .target = target,
        .optimize = optimize,
    });

    const pcre2_header_dir = b.addWriteFiles();
    const pcre2_header = pcre2_header_dir.addCopyFile(pcre2_dep.path("src/pcre2.h.generic"), "pcre2.h");

    const c = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true, // Required for most headers
    });

    c.addIncludePath(pcre2_header.dirname());
    c.defineCMacro("PCRE2_CODE_UNIT_WIDTH", "8");

    const c_mod = c.createModule();
    const global_mod = b.addModule("global", .{
        .root_source_file = b.path("src/global.zig"),
    });
    const utils_mod = b.addModule("utils", .{
        .root_source_file = b.path("src/utils.zig"),
        .imports = &.{
            .{ .name = "global", .module = global_mod },
        },
    });
    const diary_search_mod = b.addModule("diary_search", .{
        .root_source_file = b.path("src/diary_search.zig"),
        .imports = &.{
            .{ .name = "global", .module = global_mod },
            .{ .name = "utils", .module = utils_mod },
        },
    });
    const shitaraba_mod = b.addModule("shitaraba", .{
        .root_source_file = b.path("src/shitaraba.zig"),
        .imports = &.{
            .{ .name = "global", .module = global_mod },
            .{ .name = "utils", .module = utils_mod },
            .{ .name = "c", .module = c_mod },
        },
    });
    const gitup_mod = b.addModule("gitup", .{
        .root_source_file = b.path("src/gitup.zig"),
        .imports = &.{
            .{ .name = "global", .module = global_mod },
            .{ .name = "utils", .module = utils_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "do",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "global", .module = global_mod },
                .{ .name = "utils", .module = utils_mod },
                .{ .name = "diary_search", .module = diary_search_mod },
                .{ .name = "shitaraba", .module = shitaraba_mod },
                .{ .name = "gitup", .module = gitup_mod },
            },
        }),
    });

    exe.root_module.linkLibrary(pcre2_dep.artifact("pcre2-8"));
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
