const env = @import("zapp-env");
const std = @import("std");
const typez = @import("typez");

const OpenAISettings = struct {
    api_key: []const u8,
    base_url: []const u8 = "https://api.openai.com/api/v1",
};

const Sub = struct {
    is_enabled: bool = false,
    test_float: f32 = 21.0,
    string: []const u8 = "test",
};

const Settings = struct {
    sub: Sub,
};

const MyType = enum { a, b, c };

pub fn main() !void {
    const DebugAllocator = std.heap.DebugAllocator(.{});
    var da: DebugAllocator = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();
    const result = typez.loadEnv(Settings, allocator, .{
        .delimeter = "__",
        // .load_dotenv = false,
        // .prefix = "APP",
    });

    switch (result) {
        .ok => |val| {
            defer val.deinit();
            std.log.info("{any}", .{
                val.value,
            });
        },
        .err => |err| {
            std.log.info("{any}", .{
                err.message,
            });
        },
    }
}
