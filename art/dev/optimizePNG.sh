set -eu

target_dir="${1:-.}"

command -v oxipng >/dev/null || {
    echo "oxipng not installed."
    exit 1
}

jobs=$(nproc)

total=$(find "$target_dir" -type f -iname '*.png' | wc -l)

if [ "$total" -eq 0 ]; then
    echo "No PNG files found."
    exit 0
fi

echo "Found $total PNG files."
echo

counter=$(mktemp)
lock=$(mktemp)
echo 0 > "$counter"

export counter lock total

find "$target_dir" -type f -iname '*.png' -print0 |
xargs -0 -P"$jobs" -n1 sh -c '
file="$1"

orig_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")

oxipng -o max --strip safe --alpha -t 1 -q "$file"

new_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")

(
    flock 9

    count=$(cat "$counter")
    count=$((count + 1))
    echo "$count" > "$counter"

    awk -v c="$count" -v t="$total" -v name="$(basename "$file")" -v orig="$orig_size" -v new="$new_size" "
    BEGIN {
        saved = orig - new;
        if (orig > 0 && saved > 0) {
            pct = (saved / orig) * 100;
        } else {
            pct = 0;
            saved = 0;
        }
        
        if (saved >= 1048576) {
            saved_str = sprintf(\"%.2f MB\", saved / 1048576);
        } else if (saved >= 1024) {
            saved_str = sprintf(\"%.2f KB\", saved / 1024);
        } else {
            saved_str = sprintf(\"%d B\", saved);
        }

        printf \"[%d/%d] Completed: %s (Saved %s, -%.1f%%)\\n\", c, t, name, saved_str, pct;
    }"

) 9>"$lock"
' _

rm -f "$counter" "$lock"

echo
echo "Done!"