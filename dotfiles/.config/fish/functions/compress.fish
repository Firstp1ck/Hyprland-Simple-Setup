# Compress an image using ImageMagick: compress <quality> <input> <output>
function compress
    set quality $argv[1]
    set input $argv[2]
    set output $argv[3]
    magick $input -resize $quality $output
end
