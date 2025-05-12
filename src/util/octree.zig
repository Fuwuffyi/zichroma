const std = @import("std");

pub fn OctreeNode(comptime T: type) type {
    return struct {
        const Self = @This();

        children: [8]?*Self,
        values: std.ArrayList(T),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .children = .{ null } ** 8,
                .values = std.ArrayList(T).init(allocator),
            };
        }

        pub fn deinit(self: *const Self) void {
            for (self.children) |c| {
                if (c) |c_ptr| {
                    c_ptr.deinit();
                    self.values.allocator.destroy(c_ptr);
                }
            }
            self.values.deinit();
        }
    };
}

pub fn Octree(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = OctreeNode(T);
        
        pub const ExtractBitFn: type = fn (value: T) u3;
        pub const MergeValueFn: type = fn (a: T, b: T) T;

        allocator: std.mem.Allocator,
        max_depth: usize,
        count: usize,
        root: ?*Node,

        pub fn init(allocator: std.mem.Allocator, max_depth: usize) Self {
            return .{
                .allocator = allocator,
                .max_depth = max_depth,
                .count = 0,
                .root = null,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.root) |r| {
                r.deinit();
                self.allocator.destroy(r);
                self.root = null;
                self.count = 0;
            }
        }

        pub fn insert(self: *Self, value: T, bit_extract_fn: *const ExtractBitFn) !void {
            // Create root if not exists
            if (self.root == null) {
                self.root = try self.allocator.create(Node);
                self.root.?.* = Node.init(self.allocator);
            }
            // Start at root
            var node = self.root.?;
            for (0..self.max_depth) |_| {
                const idx: u3 = bit_extract_fn(value);
                if (node.children[idx] == null) {
                    node.children[idx] = try self.allocator.create(Node);
                    node.children[idx].?.* = Node.init(self.allocator);
                }
                node = node.children[idx].?;
            }
            try node.values.append(value);
            self.count += 1;
        }

        pub fn mergeSimilar(self: *Self, merge_value_fn: MergeValueFn) !void {
            _ = merge_value_fn;
            self.count -= 1;
        }

        fn collectLeaves(node: *Node, result: *std.ArrayList(T)) !void {
            var isLeaf = true;
            for (node.children) |c| {
                if (c) |_| {
                    isLeaf = false;
                    break;
                }
            }
            if (isLeaf) {
                const slice = node.values.items[0..node.values.items.len];
                for (slice) |item| {
                    try result.append(item);
                }
            } else {
                for (node.children) |c| {
                    if (c) |c_ptr| {
                        try collectLeaves(c_ptr, result);
                    }
                }
            }
        }

        pub fn values(self: *Self) ![]T {
            if (self.root == null) return &[_]T{};
            var result = std.ArrayList(T).init(self.allocator);
            try result.ensureTotalCapacity(self.count);
            try collectLeaves(self.root.?, &result);
            return result.toOwnedSlice();
        }
    };
}
