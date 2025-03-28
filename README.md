# Zig Colortheme Generator
A simple program written in Zig to generate colorthemes from a given image.

---

## Usage
The program can be simply run from the terminal, accepting the image path as argument to generate the colors from.

---

# Configuration Guide

---

## Table of Contents
1. [Core Configuration](#core-configuration)
2. [Profile Configuration](#profile-configuration)
3. [Template Configuration](#template-configuration)
4. [Examples](#examples)

---

## Core Configuration (`[core]`)
Controls global settings for color extraction and theme generation.

| Parameter         | Description                                                                                  | Default | Valid Values                     |
|-------------------|----------------------------------------------------------------------------------------------|---------|----------------------------------|
| `cluster_count`   | Number of colors to extract from the wallpaper.                                              | `4`     | Integer ≥ 1                      |
| `color_space`     | Color space used for processing the image and generating clusters.                           | `lab`   | `rgb`, `hsl`, `xyz`, `lab`       |
| `profile`         | Name of the profile to use for accent color generation (matches a `[profile.*]` section).    | `base`  | Any defined profile name         |
| `theme`           | Forces a light/dark theme or auto-detects based on the wallpaper.                            | `auto`  | `dark`, `light`, `auto`          |

---

## Profile Configuration (`[profile.*]`)
Defines how accent colors are modulated. Multiple profiles (e.g., `[profile.vibrant]`, `[profile.muted]`) can be created.

### Example: `[profile.base]`
| Parameter         | Description                                                                                  | Default | Example Format                   |
|-------------------|----------------------------------------------------------------------------------------------|---------|----------------------------------|
| `color_space`     | Color space used for applying modulations (e.g., `hsl`).                                                                                                                  | `hsl`   | `rgb`, `hsl`, `xyz`, `lab`       |
| `color_0`–`color_N` | Modulation rules for accent colors. Values are tuples: `(a, b, c)`. Use `null` to preserve the original hue. The value ranges depend on the color space of the profile. | —       | `(null, 0.33, 0.24)`             |

#### Notes:
- The color ranges are defined as follows:
   - RGB: `a, b, c` are all in range \[0, 1\]
   - HSL: `a` is in range \[0, 360\], while `b, c` are in range \[0, 1\]
   - XYZ: `a, b, c` are all in range \[0, 1\]
   - LAB: `a` is in range \[0, 100\], while `b, c` are in range \[-128, 128\]

---

## Template Configuration (`[template.*]`)
Defines input/output paths for theme templates and optional post-generation commands.

### Example: `[template.testing]`
| Parameter         | Description                                                                                  | Default | Example                          |
|-------------------|----------------------------------------------------------------------------------------------|---------|----------------------------------|
| `template_in`     | Path to the input template file (supports `~` expansion).                                    | —       | `~/Documents/template.txt`       |
| `config_out`      | Path to write the processed output file.                                                     | —       | `~/Documents/theme_output.txt`   |
| `post_cmd`        | Command to execute after generating the output (e.g., reload apps). Omit for no command.      | `null`  | `systemctl restart myapp`       |
