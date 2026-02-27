const std = @import("std");

pub fn comptimeStringToUpper(comptime string: []const u8) []const u8 {
    return comptime blk: {
        var buff: []const u8 = "";
        for (string) |l| {
            buff = buff ++ [_]u8{std.ascii.toUpper(l)};
        }
        break :blk buff;
    };
}
