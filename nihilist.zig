const std = @import("std"); 
const ascii = std.ascii;
const assert = std.debug.assert;

// Polybius square -- dropping J for 5x5
//   we can represent this in memory as a simple list of coordinates
//   since the size of the list is bounded to 25
//   to lookup some letter X, we subtract ascii(X) to get an idx to the list
//
//   Polybius squares are typically 1-indexed, so with a normal alphabet A == 1,1
pub const Polybius = struct {
    pub const Point = struct {
        row: u3,
        col: u3,
    };

    ltr_map: [25]?Point,

    pub fn init(key: []const u8) Polybius {
        var ltr_map: [25]?Point = [_]?Point{null} ** 25;
        var it = initIter(key);

        var ri: u3 = 1;
        while (ri <= 5) : (ri += 1) {
            var ci: u3 = 1;
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

    pub fn deinit() void {}

    pub fn get(ltr: u8) Point {}

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

test "polybius" {
    var polybius = Polybius.init("zebra");
    std.debug.warn("\n{}\n", .{polybius});
    for (polybius.ltr_map) |point| {
        std.debug.warn("{}\n", .{point});
    }
}
