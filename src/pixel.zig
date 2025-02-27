pub const Pixel = packed struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn eql(self: *const @This(), other: *const Pixel) bool {
        return self.r == other.r and self.g == other.g and self.b == other.b and self.a == other.a;
    }
};
