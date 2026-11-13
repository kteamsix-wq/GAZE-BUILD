find . -type d -name ".haxelib" -prune -o -type f -name "*.png" -print | while read -r file; do
    if [[ "$file" =~ /export/ ]]; then
        continue
    fi

    echo "Processing: $file"
    
    dir=$(dirname "$file")
    filename=$(basename "$file" .png)

    ffmpeg -y -i "$file" -c:v libwebp -lossless 1 -compression_level 6 -quality 100 "$dir/$filename.webp" && rm "$file"
done

echo
echo "Done!"