const std = @import("std");
const ParseError = @import("../models.zig").ParseError;

pub fn parseBool(buff: []const u8) ParseError!bool {
    if (buff.len > 5) {
        return ParseError.InvalidBoolField;
    }
    var bfr: [5]u8 = undefined;
    const cmp_str = std.ascii.lowerString(bfr[0..buff.len], buff);
    const truthy_values = [_][]const u8{
        "true",
        "t",
        "1",
    };
    const falsey_values = [_][]const u8{
        "false",
        "f",
        "0",
    };
    inline for (truthy_values) |val| {
        if (std.mem.eql(u8, cmp_str, val)) {
            return true;
        }
    }
    inline for (falsey_values) |val| {
        if (std.mem.eql(u8, cmp_str, val)) {
            return false;
        }
    }
    return ParseError.InvalidBoolField;
}

pub fn parseEnum(comptime T: type, buff: []const u8) ParseError!T {
    const result = std.meta.stringToEnum(T, buff);
    if (result) |res| {
        return res;
    } else {
        std.log.err("Invalid Enum Field: '{s}' for type '{s}'", .{
            buff,
            @typeName(T),
        });
        return ParseError.InvalidEnumField;
    }
}

pub fn parsePointer(comptime T: type, allocator: std.mem.Allocator, buff: []const u8) !T {
    const info = @typeInfo(T).pointer;
    if (info.is_const and info.child == u8) {
        // it's a string, treat it as a string
        // duplicate it so the allocator owns the memory
        return try allocator.dupe(u8, buff);
    } else {
        @compileError("'" ++ @typeName(T) ++ "' pointers are not supported yet...");
    }
}

pub fn parse(comptime T: type, allocator: std.mem.Allocator, buff: []const u8) !T {
    return switch (@typeInfo(T)) {
        .bool => try parseBool(buff),
        .@"enum" => try parseEnum(T, buff),
        .int => std.fmt.parseInt(T, buff, 10) catch ParseError.InvalidIntField,
        .float => std.fmt.parseFloat(T, buff) catch ParseError.InvalidFloatField,
        .pointer => try parsePointer(T, allocator, buff),
        // TODO: handle array parsing
        // .array => |t| {
        //     switch (@typeInfo(t.child)) {
        //         .int => |_| {},
        //         else => {},
        //     }
        // },

        // TODO: Handle parsing strings
        else => |C| @compileError(@tagName(C) ++ " types are not yet supported."),
    };
}

pub fn validate(comptime T: type) void {
    comptime var found = false;
    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (field.type == *std.heap.ArenaAllocator) {
            found = true;
            break;
        }
    }
    if (!found) {
        @compileError("Couldn't find a type *std.heap.ArenaAllocator");
    }
}

