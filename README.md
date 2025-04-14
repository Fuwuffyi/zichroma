# Zichroma
A simple program written in Zig to generate colorthemes from a given image.

---

## Usage
The program can be simply run from the terminal, accepting the image path as argument to generate the colors from.

---

# Configuration Guide
Guide on how to configure the program to suit your own needs.

---

## Table of Contents
1. [Config File Setup](#config-file-setup)
2. [Core Configuration](#core-configuration-core)
3. [Profile Configuration](#profile-configuration-profile)
4. [Template Configuration](#template-configuration-template)
5. [Template file structure](#template-file-structure)

---

## Config file setup
The file must be named `config.conf` and must be placed in the following directories:
- **Linux**: `$XDG_CONFIG_HOME/zichroma/config.conf` or `$HOME/zichroma/config.conf`
- **MacOS**: `$HOME/Library/Application Support/zichroma/config.conf`
- **Windows**: `%APPDATA%/zichroma/config.conf`  

Alternatively, the config file can be placed in the same directory of the executable.

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

---

## Template file structure
The template file can contain any kinds of text as the code will only replace sections within the `template_in` contained within `{{ 'property' }}`.  
The property tag of the color is structured as follows:
- `color<idx>`: Is the base cluster to get the color from (`<idx>` is a number 0..`cluster_count`).
- `<pri|txt|acc>`: Are used to choose which type of color to pick out of the three categories.
- `<idx>`: Another index is needed for accent colors, are there can be any number (0..`number of colors in profile`)
- `<property>`: The property defines which part of the color, and which format to use when replacing the text. It can have the following types:
   - `<r|g|b>`: To get the r,g,b property in range \[0, 255\].
   - `<rh|gh|bh>`: Same thing as above, but hexadecimal \[00, FF\].
   - `<rgb>`: Returns an rgb tuple: `r, g, b`, with the values in the range \[0, 255\].
   - `<hex>`: Returns an rgb hex string in the range of \[000000, FFFFFF\].  

A few examples are as follows:
- `color0.txt.rgb`: will return from the first cluster's txt color a tuple like (2, 255, 0).
- `color2.acc4.hex`: will return from the third cluster's color, using the fifth accent color, an hex string like (2351FF).
- `color1.pry.r`: will only return the 'red' value from the second cluster's primary color (255 for example).
- `color3.pry.bh`: will only return the 'blue' value from the fourth cluster's primary color in hex (FF for example).

---

#### Final notes:
This project was heavily inspired by simplar projects: [Pywal](https://github.com/dylanaraps/pywal), [Wallbash](https://github.com/prasanthrangan/hyprdots/wiki/Wallbash), [Matugen](https://github.com/InioX/matugen).  
*"Go forth and make the world adowable~"* 🐺💻🎨
