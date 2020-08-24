const std = @import("std"); 
const fmt = std.fmt;
const mem = std.mem;
const ascii = std.ascii;
const assert = std.debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

// Polybius square -- dropping J for 5x5
//   we can represent this in memory as a simple list of coordinates
//   since the size of the list is bounded to 25
//   to lookup some letter X, we subtract ascii(X) to get an idx to the list
//   to lookup some Point (r,c), we also maintain a HashMap to ltr
//
//   Polybius squares are typically 1-indexed, so with a normal alphabet A == 1,1
pub const Polybius = struct {
    pub const Point = struct {
        row: u4,
        col: u4,
    };

    allocator: *mem.Allocator,
    ltr_map: []?Point,
    point_map: AutoHashMap(Point, u8),

    pub fn init(allocator: *mem.Allocator, key: []const u8) !Polybius {
        var ltr_map = try allocator.alloc(?Point, 25);
        for (ltr_map) |*point| {
            point.* = null;
        }
        var point_map = AutoHashMap(Point, u8).init(allocator);
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
                        _ = try point_map.put(ltr_map[idx].?, ascii.toUpper(ltr));
                        break;
                    }
                }
            }
        }

        return Polybius{
            .allocator = allocator,
            .ltr_map = ltr_map,
            .point_map = point_map,
        };
    }

    pub fn deinit(self: *Polybius) void {
        self.point_map.deinit();
        self.allocator.free(self.ltr_map);
    }

    pub fn getPoint(self: Polybius, ltr: u8) ?Point {
        if (!ascii.isAlpha(ltr)) return null;
        return self.ltr_map[ltrToIdx(ltr)];
    }

    pub fn getLetter(self: Polybius, point: Point) ?u8 {
        assert(point.row <= 5 and point.col <= 5);
        return self.point_map.get(point);
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

    pub fn init(allocator: *mem.Allocator, key_a: []const u8, key_b: []const u8) !Nihilist {
        for (key_b) |ltr| {
            assert(ascii.isAlpha(ltr));
        }
        return Nihilist{
            .square = try Polybius.init(allocator, key_a),
            .allocator = allocator,
            .key = key_b,
        };
    }

    pub fn deinit(self: *Nihilist) void {
        self.square.deinit();
    }

    // Caller owns returned memory
    pub fn encrypt(self: Nihilist, plaintext: []const u8) ![]u8 {
        // 1. Get row/col of each plaintext letter
        // 2. Get row/col of each key letter
        // 3. Add key row to plaintext row, key col to plaintext col
        // 4. Concat row/col sum into a 2-3 digit number
        var payload = try ArrayList(u8).initCapacity(self.allocator, plaintext.len * 2);
        var key_idx: usize = 0;
        for (plaintext) |ltr, idx| {
            var pt_point = self.square.getPoint(ltr) orelse continue;
            var key_point = self.square.getPoint(self.key[key_idx]).?;
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

    pub fn decrypt(self: Nihilist, ciphertext: []const u8) ![]u8 {
        // 1. Split on spaces, get chunks
        // 2. Get point from chunk
        // 3. Subtract key point row from extracted row; same for col
        // 4. Deref points into letters from square
        var plaintext = try ArrayList(u8).initCapacity(self.allocator, ciphertext.len / 2);

        var chunk_it = mem.split(ciphertext, " ");
        var key_idx: usize = 0;
        var decoded_count: usize = 0;
        while (chunk_it.next()) |chunk| {
            var ct_point = try self.pointFromCiphertextChunk(chunk);
            var key_point = self.square.getPoint(self.key[key_idx]).?;
            key_idx = (key_idx + 1) % self.key.len;

            if (ct_point.row <= key_point.row or ct_point.col <= key_point.col) {
                return error.InvalidKey;
            }
            var pt_point = Polybius.Point{
                .row = ct_point.row - key_point.row,
                .col = ct_point.col - key_point.col,
            };
            var ltr = self.square.getLetter(pt_point);
            if (ltr == null) {
                return error.InvalidKey;
            }

            try plaintext.append(ltr.?);
            decoded_count += 1;
        }

        plaintext.shrink(decoded_count);
        
        return plaintext.toOwnedSlice();
    }

    fn pointFromCiphertextChunk(self: Nihilist, chunk: []const u8) !Polybius.Point {
        // If chunk is 2 digits, extract (r)(c)
        // If chunk is 3 digits, find the "1"; double digit will follow the 1
        // If chunk is 4 digits, split down middle 
        var row: u4 = undefined;
        var col: u4 = undefined;
        switch (chunk.len) {
            2 => {
                row = try fmt.parseInt(u4, chunk[0..1], 10);
                col = try fmt.parseInt(u4, chunk[1..], 10);
            },
            3 => {
                if (chunk[0] == '1') {
                    row = try fmt.parseInt(u4, chunk[0..2], 10);
                    col = try fmt.parseInt(u4, chunk[2..], 10);
                } else {
                    row = try fmt.parseInt(u4, chunk[0..1], 10);
                    col = try fmt.parseInt(u4, chunk[1..], 10);
                }
            },
            4 => {
                row = try fmt.parseInt(u4, chunk[0..2], 10);
                col = try fmt.parseInt(u4, chunk[2..], 10);
            },
            else => {
                return error.InvalidCiphertext;
            }
        }
        return Polybius.Point{
            .row = row,
            .col = col,
        };
    }
};

test "polybius" {
    var polybius = try Polybius.init(testing.allocator, "zebras");
    defer polybius.deinit();
    for (polybius.ltr_map) |point| {
        assert(point != null);
    }
}

test "nihilist" {
    var allocator = testing.allocator;
    var nihilist = try Nihilist.init(allocator, "zebras", "russian");
    defer nihilist.deinit();

    var enc = try nihilist.encrypt("DYNAMITE WINTER PALACE");
    defer allocator.free(enc);

    var expected = "37 106 62 36 67 47 86 26 104 53 62 77 27 55 57 66 55 36 54 27";
    testing.expectEqualSlices(u8, enc, expected);

    var dec = try nihilist.decrypt(enc);
    defer allocator.free(dec);

    var expected_dec = "DYNAMITEWINTERPALACE";
    testing.expectEqualSlices(u8, dec, expected_dec);
}
