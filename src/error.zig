const std = @import("std");

const errorMessages: std.StaticStringMap([]const u8) = std.StaticStringMap([]const u8).initComptime(.{
    // General
    .{"UnsupportedOS", "Your OS is currently unsupported, please write an issue or make a pr on github."},
    .{"FileCreationError", "Could not create file: {s}."},
    .{"FileOpenError", "Could not open file: {s}."},
    .{"MissingHomeDir", "Could not read $XDG_CACHE_HOME nor $HOME env vars."},
    .{"MissingLocalAppData", "Could not locate AppData directory."},
    // Clustering errors
    .{"EmptyPalette", "The palette of the current image is empty."},
    .{"InvalidK", "The cluster_count value is invalid."},
    // Cache errors
    .{"InvalidData", "The cache file is invalid.\nPath: {s}"},
    // Config errors
    .{"ConfigFileNotFound", "Could not locate a valid config file. Put one in '~/.config/zichroma/config.conf'."},
    .{"ProfileNotFound", "The profile ({s}) is not defined in the config file."},
    .{"InvalidColorSpace", "The color space ({s}) is not valid.\nPossible values: (rgb, hsl, xyz, lab)."},
    .{"InvalidTheme", "The theme ({s}) is not valid.\nPossible values: (light, dark, auto)."},
    .{"UnknownCoreSetting", "Option ({s}) not valid in Core."},
    .{"InvalidSectionHeader", "The section header is invalid.\nLine: {s}"},
    .{"UnknownSection", "The section ({s}) is unknown.\nLine: {s}"},
    .{"InvalidKeyValue", "Key value pair not valid.\nLine: {s}"},
    .{"TooFewModulationValues", "There are not enough modulation values.\nCurrent values: {s}\nExample: (255, 100, 25)"},
    .{"TooManyModulationValues", "There are too many modulation values.\nCurrent values: {s}\nExample: (255, 100, 25)"},
    .{"UnknownProfileSetting", "Option ({s}) not valid in Profile."},
    .{"TemplateNotFound", "Template ({s}) is not defined in the config file."},
    .{"UnknownTemplateSetting", "Option ({s}) not valid in Template."},
    .{"OrphanedKeyValue", "The value for ({s}) is not within any section."},
    // Template errors
    .{"UnterminatedPlaceholder", "One of the placeholder variables has not been closed.\nPosition: {}"},
    .{"UnknownColorType", "The color type ({s}) is not defined.\nPossible values: (pri, txt, acc)."},
    .{"InvalidColorSpec", "The variable does not start with color.\nVariable: {s}"},
    .{"InvalidColorIndex", "The index ({s}) for the color provided is not valid.\nVariable: {s}"},
    .{"ColorIndexOutOfBounds", "The index ({}) for the color provided is out of bounds (must be >= 0 and < cluster_count).\nVariable: {s}"},
    .{"InvalidAccentIndex", "The index ({s}) for the accent provided is not valid."},
    .{"AccentIndexOutOfBounds", "The index ({}) for the color provided is out of bounds (must be >= 0 and < profile color count)."},
    .{"InvalidPlaceholderFormat", "The placeholder variable ({s}) is invalid."},
    .{"InvalidColorProperty", "The color property ({s}) is not defined.\nCheck the documentation for all the properties."},
    .{"CommandFailed", "The command ({s}) exited unexpectedly."}
});

pub fn logError(comptime err: anyerror, args: anytype) anyerror {
    const key: [:0]const u8 = comptime @errorName(err);
    comptime {
        if (!errorMessages.has(key)) {
            @compileError("The error " ++ key ++ " has no associated string.");
        }
    }
    std.log.err(errorMessages.get(key).?, args);
    return err;
}
