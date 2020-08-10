const std = @import("std"); 
const fmt = std.fmt;
const mem = std.mem;
const ascii = std.ascii;
const assert = std.debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;

// Polybius square -- dropping J for 5x5
//   we can represent this in memory as a simple list of coordinates
//   since the size of the list is bounded to 25
//   to lookup some letter X, we subtract ascii(X) to get an idx to the list
//
//   Polybius squares are typically 1-indexed, so with a normal alphabet A == 1,1
pub const Polybius = struct {
    pub const Point = struct {
        row: u4,
        col: u4,
    };

    ltr_map: [25]?Point,

    pub fn init(key: []const u8) Polybius {
        var ltr_map: [25]?Point = [_]?Point{null} ** 25;
        var it = initIter(key);

        var ri: u4 = 1;
        while (ri <= 5) : (ri += 1) {
            var ci: u4 = 1;
            while (ci <= 5) : (ci += 1) {
                while (it.next()) |ltr| {
                    var idx = ltrToIdx(ltr);
                    if (ltr_map[idx]) |_| {
                        continue;
                    } else {
                        ltr_map[idx] = Point{
                            .row = ri,
                            .col = ci,
                        };
                        break;
                    }
                }
            }
        }

        return Polybius{
            .ltr_map = ltr_map,
        };
    }

    pub fn deinit(self: Polybius) void {}

    pub fn get(self: Polybius, ltr: u8) ?Point {
        if (!ascii.isAlpha(ltr)) return null;
        return self.ltr_map[ltrToIdx(ltr)];
    }

    fn ltrToIdx(letter: u8) usize {
        assert(ascii.isAlpha(letter));
        var ltr_up = ascii.toUpper(letter);
        if (ltr_up == 'J') {
            return 'I';
        } else if (ltr_up > 'J') {
            return ltr_up - 'A' - 1;
        } else {
            return ltr_up - 'A';
        }
    }

    fn initIter(key: []const u8) Iterator {
        return Iterator{
            .key = key,
            .idx = 0,
        };
    }

    const Iterator = struct {
        const alphabet = "ABCDEFGHIKLMNOPQRSTUVWXYZ";

        idx: usize,
        key: []const u8,

        fn next(it: *Iterator) ?u8 {
            if (it.idx >= it.key.len + alphabet.len) return null;

            var next_ltr = if (it.idx >= it.key.len) alphabet[it.idx - it.key.len] else it.key[it.idx];

            it.idx += 1;

            return next_ltr;
        }
    };
};

pub const Nihilist = struct {
    square: Polybius,
    key: []const u8,
    allocator: *mem.Allocator,

    pub fn init(allocator: *mem.Allocator, key_a: []const u8, key_b: []const u8) Nihilist {
        for (key_b) |ltr| {
            assert(ascii.isAlpha(ltr));
        }
        return Nihilist{
            .square = Polybius.init(key_a),
            .allocator = allocator,
            .key = key_b,
        };
    }

    pub fn deinit(self: Nihilist) void {}

    // Caller owns returned memory
    pub fn encrypt(self: Nihilist, plaintext: []const u8) ![]u8 {
        // 1. Get row/col of each plaintext letter
        // 2. Get row/col of each key letter
        // 3. Add key row to plaintext row, key col to plaintext col
        // 4. Concat row/col sum into a 2-3 digit number
        var payload = try ArrayList(u8).initCapacity(self.allocator, plaintext.len * 2);
        var key_idx: usize = 0;
        for (plaintext) |ltr, idx| {
            var pt_point = self.square.get(ltr) orelse continue;
            var key_point = self.square.get(self.key[key_idx]).?;
            key_idx = (key_idx + 1) % self.key.len;

            var enc = try fmt.allocPrint(self.allocator, "{}{} ", .{
                pt_point.row + key_point.row,
                pt_point.col + key_point.col,
            });
            defer self.allocator.free(enc);
            try payload.appendSlice(enc);
        }
        
        // there's an extra space on the end, so take it off
        payload.shrink(payload.items.len - 1);
        return payload.toOwnedSlice();
    }

    pub fn decrypt(self: Nihilist, ciphertext: []const u8) []u8 {}
};

test "polybius" {
    var polybius = Polybius.init("zebras");
    for (polybius.ltr_map) |point| {
        assert(point != null);
    }
}

test "nihilist" {
    var allocator = testing.allocator;
    var nihilist = Nihilist.init(allocator, "zebras", "russian");
    var enc = try nihilist.encrypt("DYNAMITE WINTER PALACE");
    defer allocator.free(enc);
    var expected = "37 106 62 36 67 47 86 26 104 53 62 77 27 55 57 66 55 36 54 27";
    testing.expectEqualSlices(u8, enc, expected);
}
