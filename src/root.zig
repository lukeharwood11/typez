const std = @import("std");

const scoped_logger = std.log.scoped(.@"zapp-env");

pub fn printTest(input: []const u8) void {
    scoped_logger.info("{s}", .{input});
}
