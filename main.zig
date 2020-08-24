const std = @import("std");
const Nihilist = @import("nihilist.zig").Nihilist;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var allocator = &arena.allocator;

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.warn("Usage: nihilist <encrypt|decrypt> <polybius_key> <nihilist_key> <plaintext|ciphertext>\n", .{});
        return;
    }

    var enc = std.mem.eql(u8, args[1], "encrypt");
    var dec = std.mem.eql(u8, args[1], "decrypt");

    if (!(enc or dec)) {
        std.debug.warn("Usage: nihilist <encrypt|decrypt> <polybius_key> <nihilist_key> <plaintext|ciphertext>\n", .{});
        return;
    }

    var nihilist = try Nihilist.init(allocator, args[2], args[3]);

    var output = if (dec) try nihilist.decrypt(args[4]) else try nihilist.encrypt(args[4]);
    std.debug.warn("{}\n", .{output});
}
