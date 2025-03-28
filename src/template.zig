const color = @import("color.zig");

pub const TemplateValue = struct {
    primary_color: color.Color,
    text_color: color.Color,
    accent_colors: []const color.Color
};
