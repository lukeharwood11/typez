const env = @import("zapp-env");
const std = @import("std");

const OpenAISettings = struct {
    api_key: []const u8,
    base_url: []const u8 = "https://api.openai.com/api/v1",
};

const Sub = struct {
    is_enabled: bool = false,
    test_float: f32 = 21.0,
    string: []const u8 = "test",
};

const Config = struct {
    prefix: []const u8 = "",
    delimeter: []const u8 = "_",
    // TODO: implement dotenv loading
    // load_dotenv: bool = false,

    const default: Config = .{};
};

const Settings = struct {
    // arena: *std.heap.ArenaAllocator,
    sub: Sub,
    pub const config: Config = .default;
};

pub fn Result(comptime T: type) type {
    return struct {
        arena: *std.heap.ArenaAllocator,
        value: T,

        pub fn deinit(self: @This()) void {
            self.arena.deinit();
            self.arena.child_allocator.destroy(self.arena);
        }
    };
}

const ParseError = error{
    InvalidEnumField,
    InvalidFloatField,
    InvalidIntField,
    InvalidNullField,
    InvalidBoolField,
    OutOfMemory,
};

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

pub fn getVarFromMap(T: type, allocator: std.mem.Allocator, env_map: *std.process.EnvMap, key: []const u8, default: ?T) !T {
    const optional = env_map.get(key);
    if (optional) |env_var| {
        return parse(T, allocator, env_var);
    } else {
        if (default) |d| {
            return d;
        } else if (@typeInfo(T) == .optional) {
            return null;
        } else {
            std.log.err("No environment variable for '{s}'", .{key});
            return ParseError.InvalidNullField;
        }
    }
}

pub fn comptimeStringToUpper(comptime string: []const u8) []const u8 {
    return comptime blk: {
        var buff: []const u8 = "";
        for (string) |l| {
            buff = buff ++ [_]u8{std.ascii.toUpper(l)};
        }
        break :blk buff;
    };
}

pub fn formatCombine(
    comptime config: Config,
    comptime namespace: []const u8,
    comptime new: []const u8,
) []const u8 {
    const delimeter: []const u8 = if (namespace.len == 0 and config.prefix.len == 0) "" else config.delimeter;
    const string = (if (namespace.len == 0) config.prefix else namespace) ++ delimeter ++ new;
    return comptimeStringToUpper(string);
}

pub fn loadStructFromEnv(
    comptime T: type,
    allocator: std.mem.Allocator,
    env_map: *std.process.EnvMap,
    comptime config: Config,
    comptime namespace: []const u8,
) !T {
    var t: T = undefined;
    inline for (@typeInfo(T).@"struct".fields) |field| {
        const default = field.defaultValue();
        std.log.info("Found default: {any}", .{default});
        switch (@typeInfo(field.type)) {
            .@"struct" => {
                @field(t, field.name) = try loadStructFromEnv(
                    field.type,
                    allocator,
                    env_map,
                    config,
                    formatCombine(config, namespace, field.name),
                );
            },
            else => {
                const key = formatCombine(config, namespace, field.name);
                std.log.info("Checking key: {s}", .{key});
                @field(t, field.name) = try getVarFromMap(field.type, allocator, env_map, key, default);
            },
        }
    }
    return t;
}

pub fn loadEnv(comptime T: type, allocator: std.mem.Allocator, comptime config: Config) !Result(T) {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();
    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    const settings = try loadStructFromEnv(T, arena.allocator(), &env_map, config, "");
    return .{
        .arena = arena,
        .value = settings,
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
//
// pub fn load(comptime T: type, allocator: std.mem.Allocator) !T {
//     const map = try std.process.getEnvMap(allocator);
//     defer map.deinit();
//
//     comptime var config: Config = .default;
//     inline for (@typeInfo(T).@"struct".decls) |decl| {
//         const field = @field(T, decl.name);
//         std.log.info("Type: {s} - {s}", .{ @typeName(@TypeOf(field)), decl.name });
//         if (@TypeOf(field) == Config) {
//             std.log.info("I found a config!: {any}", .{field});
//             config = field;
//             break;
//         }
//     }
//
//     return T{};
// }
//
const MyType = enum { a, b, c };

pub fn main() !void {
    const DebugAllocator = std.heap.DebugAllocator(.{});
    var da: DebugAllocator = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();
    const result = try loadEnv(Settings, allocator, .{
        .delimeter = "__",
        // .load_dotenv = false,
        // .prefix = "APP",
    });
    const settings = result.value;
    defer result.deinit();

    // const number = try parse([1]u8, "[1, 2, 3, 4]");
    // std.log.info("{d}", .{number});
    // const result = try parse(MyType, "c");
    // const result = try parseBool("true");
    std.log.info("{any}", .{
        settings,
    });
}
