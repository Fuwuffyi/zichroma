const std = @import("std");

fn OctreeNode(comptime T: type) type {
    return struct {
        const Self = @This();

        children: [8]?*Self,
        values: std.ArrayList(T),

        fn init(allocator: std.mem.Allocator) Self {
            return .{
                .children = .{ null } ** 8,
                .values = std.ArrayList(T).init(allocator),
            };
        }

        fn deinit(self: *const Self) void {
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
        
        pub const ExtractBitFn: type = fn (value: T, depth: usize) u3;
        pub const MergeValueFn: type = fn (a: T, b: T) T;

        allocator: std.mem.Allocator,
        // Limits the amount of depth in the tree, after which, the leaf node will have no capacity limit.
        max_depth: usize,
        // Limits the capacity of elements in a node before splitting it.
        node_count_limit: usize,
        len: usize,
        root: *Node,

        pub fn init(allocator: std.mem.Allocator, max_depth: usize, node_limit: usize) !Self {
            const root: *Node = try allocator.create(Node);
            root.* = Node.init(allocator);
            return .{
                .allocator = allocator,
                .max_depth = max_depth,
                .node_count_limit = node_limit,
                .len = 0,
                .root = root,
            };
        }

        pub fn deinit(self: *Self) void {
            self.root.deinit();
            self.allocator.destroy(self.root);
            self.len = 0;
        }

        pub fn insert(self: *Self, value: T, bit_extract_fn: ExtractBitFn) !void {
            try self.insertRecursive(self.root, value, bit_extract_fn, 0);
            self.len += 1;
        }

        fn insertRecursive(self: *Self, node: *Node, value: T, bit_extract_fn: ExtractBitFn, depth: usize) !void {
            if (depth >= self.max_depth) {
                try node.values.append(value);
                return;
            }
            // Add the element if there is space
            try node.values.append(value);
            if (node.values.items.len > self.node_count_limit) {
                // If element count too high, split node
                for (0..8) |i| {
                    if (node.children[i] == null) {
                        node.children[i] = try self.allocator.create(Node);
                        node.children[i].?.* = Node.init(self.allocator);
                    }
                }
                // Redistribute values
                for (node.values.items) |existing| {
                    const oct = bit_extract_fn(existing, depth);
                    try self.insertRecursive(node.children[oct].?, existing, bit_extract_fn, depth + 1);
                }
                // Clear items on current node
                node.values.clearAndFree();
            }
        }

        pub fn merge(self: *Self, merge_value_fn: MergeValueFn) !void {
            _ = merge_value_fn;
            self.len -= 1;
        }

        fn collectLeaves(node: *Node, result: *std.ArrayList(T)) !void {
            var is_leaf: bool = true;
            for (node.children) |c| {
                if (c) |_| {
                    is_leaf = false;
                    break;
                }
            }
            if (is_leaf) {
                const slice: []T = node.values.items[0..node.values.items.len];
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
            var result: std.ArrayList(T) = std.ArrayList(T).init(self.allocator);
            try result.ensureTotalCapacity(self.len);
            try collectLeaves(self.root, &result);
            return result.toOwnedSlice();
        }
    };
}
