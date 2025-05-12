const std = @import("std");

pub fn OctreeNode(comptime T: type) type {
    return struct {
        const Self = @This();

        children: [8]?*Self,
        values: std.ArrayList(T),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .children = .{ null, null, null, null, null, null, null, null },
                .values = std.ArrayList(T).init(allocator),
            };
        }

        pub fn deinit(self: *const Self) void {
            self.values.deinit();
            for (self.children) |c| {
                if (c) |c_ptr| {
                    c_ptr.deinit();
                    self.values.allocator.destroy(c_ptr);
                }
            }
        }
    };
}

pub fn Octree(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const ExtractBitFn: type = fn (value: T) u3;

        allocator: std.mem.Allocator,
        max_depth: usize,
        root: ?*OctreeNode(T),

        pub fn init(allocator: std.mem.Allocator, max_depth: usize) Self {
            return .{
                .allocator = allocator,
                .max_depth = max_depth,
                .root = null,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.root) |r| {
                r.deinit();
                self.allocator.destroy(r);
                self.root = null;
            }
        }

        pub fn insert(self: *Self, value: T, bit_extract_fn: *const ExtractBitFn) !void {
            // Create root if not exists
            if (self.root == null) {
                self.root = try self.allocator.create(OctreeNode(T));
                self.root.?.* = OctreeNode(T).init(self.allocator);
            }
            // Start at root
            var node = self.root.?;
            for (0..self.max_depth) |_| {
                try node.values.append(value);
                const idx: u3 = bit_extract_fn(value);
                if (node.children[idx] == null) {
                    node.children[idx] = try self.allocator.create(OctreeNode(T));
                    node.children[idx].?.* = OctreeNode(T).init(self.allocator);
                }
                node = node.children[idx].?;
            }
            try node.values.append(value);
        }
    };
}
