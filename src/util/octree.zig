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
            // If at max depth, just append
            if (depth >= self.max_depth) {
                try node.values.append(value);
                return;
            }
            // If split, descend
            if (node.children[0] != null) {
                const oct: u3 = bit_extract_fn(value, depth);
                try self.insertRecursive(node.children[oct].?, value, bit_extract_fn, depth + 1);
                return;
            }
            // Add the element if there is space and not split node
            if (node.values.items.len > self.node_count_limit) {
                // If element count too high, split node
                for (0..8) |i| {
                    node.children[i] = try self.allocator.create(Node);
                    node.children[i].?.* = Node.init(self.allocator);
                }
                // Redistribute values
                for (node.values.items) |existing| {
                    const oct: u3 = bit_extract_fn(existing, depth);
                    try self.insertRecursive(node.children[oct].?, existing, bit_extract_fn, depth + 1);
                }
                // Clear items on current node
                node.values.clearAndFree();
                // Add new item
                const newOct = bit_extract_fn(value, depth);
                try self.insertRecursive(node.children[newOct].?, value, bit_extract_fn, depth + 1);
                return;
            }
            try node.values.append(value);
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

        // FIXME: Remove once octree fully functional
        pub fn print(self: *Self) void {
            self.printRecursive(self.root, 0);
        }

        fn printRecursive(self: *Self, node: *Node, depth: usize) void {
            if (node.values.items.len > 0) {
                std.debug.print("depth: {d}\n", .{depth});
            }
            const slice = node.values.items[0..node.values.items.len];
            var count: u32 = 0;
            for (slice) |v| {
                if (count >= 8) break;
                const primary_color = v.clr.convertTo(.rgb).values;
                std.debug.print("\x1B[48;2;{};{};{}m          \x1B[0m\n", .{ @as(u32, @intFromFloat(primary_color[0] * 255)), @as(u32, @intFromFloat(primary_color[1] * 255)), @as(u32, @intFromFloat(primary_color[2] * 255)) });
                count += 1;
            }
            if (node.values.items.len > 0) {
                std.debug.print("\n", .{});
            }
            for (node.children) |child| {
                if (child) |c_ptr| {
                    self.printRecursive(c_ptr, depth + 1);
                }
            }
        }
    };
}
