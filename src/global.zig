const std = @import("std");
const mem = std.mem;
const Io = std.Io;
const process = std.process;

pub var allocator: mem.Allocator = undefined;
pub var environ_map: *process.Environ.Map = undefined;
pub var io: Io = undefined;
pub var stdout: *Io.Writer = undefined;
pub var stderr: *Io.Writer = undefined;
