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

        allocator: std.mem.Allocator,
        root: ?*OctreeNode(T),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
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
    };
}
