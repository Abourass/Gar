#!/usr/bin/env fish

# By default `arts` will convert all the png files in the current directory to webp
# Optionally, you can specify `-r` to recursively convert png files in subdirectories as well
# you can also specify `-c` to remove the original png files after conversion
# Finally, you can specify `-s` to rename the converted webp files to shiskabob-case
# (spaces replaced with hyphens, but doesn't change the case of the letters)
function arts --description 'Convert PNG to WebP, optionally recurse, clean originals, and kebab-rename'
    argparse h/help r/recursive c/clean s/shiskabob l/lossless q/quality= -- $argv
    or return 1

    if set -q _flag_help
        echo "arts - convert PNG files to WebP"
        echo
        echo "Usage: arts [-r] [-c] [-s] [-l] [-q N]"
        echo "  -r/--recursive   also convert PNGs in subdirectories"
        echo "  -c/--clean       delete the original PNG after a successful conversion"
        echo "  -s/--shiskabob   replace spaces in the output filename with hyphens"
        echo "  -l/--lossless    encode losslessly (perfect quality, ignores visual -q)"
        echo "  -q/--quality N   quality 0-100 (lossy: higher=better/bigger;"
        echo "                   with -l: compression effort, higher=smaller/slower)"
        return 0
    end

    if not command -q cwebp
        echo "arts: 'cwebp' not found. Install it with: brew install webp" >&2
        return 1
    end

    # Validate -q up front so a typo fails here with a clear message instead of
    # producing a cryptic error from cwebp on every single file.
    if set -q _flag_quality
        if not string match -qr '^[0-9]+$' -- $_flag_quality; or test $_flag_quality -gt 100
            echo "arts: --quality must be an integer between 0 and 100" >&2
            return 1
        end
    end

    # Assemble the cwebp options once and reuse them for every file. -lossless and
    # -q can coexist: in lossless mode cwebp reinterprets -q as a speed/size knob
    # (0 = fast & larger, 100 = slow & smallest) rather than visual quality.
    set -l cwebp_opts -quiet
    set -q _flag_lossless; and set -a cwebp_opts -lossless
    set -q _flag_quality; and set -a cwebp_opts -q $_flag_quality

    # Collect the PNG files with `find` rather than a glob. This buys us three things:
    #   1. No fish "No matches for wildcard" error when a directory has zero PNGs.
    #   2. -maxdepth cleanly toggles recursion on/off.
    #   3. Paths come back prefixed with ./ , which protects any filename that
    #      happens to start with a dash from being read as a flag.
    set -l find_args .
    if not set -q _flag_recursive
        set -a find_args -maxdepth 1
    end
    set -a find_args -type f -iname '*.png'

    set -l files (find $find_args)
    if test (count $files) -eq 0
        echo "arts: no PNG files found"
        return 0
    end

    set -l converted 0
    for file in $files
        # foo.png -> foo.webp  (-i so .PNG is matched too; replacement stays lowercase)
        set -l out (string replace -ri '\.png$' '.webp' -- $file)

        # -s: rewrite spaces in the *basename* only, leaving any parent dirs untouched
        if set -q _flag_shiskabob
            set -l dir (path dirname -- $out)
            set -l base (path basename -- $out)
            set out $dir/(string replace -a ' ' '-' -- $base)
        end

        if cwebp $cwebp_opts $file -o $out
            set converted (math $converted + 1)
            if set -q _flag_clean
                rm -- $file
            end
        else
            echo "arts: failed to convert $file" >&2
        end
    end

    echo "arts: converted $converted file(s) to WebP"
end
