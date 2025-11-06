
# Inline edit: apply command to file in-place
# Usage: inplace FILE COMMAND [ARGS...]
# Example: inplace myfile.txt sed 's/foo/bar/g'
function inplace()
{
  local file=$1
  shift
  (rm "$file" && "$@" > "$file") < "$file"
}

# Add indentation to each line of input
# Usage: indent N [INPUT]
# Example: echo "hello\nworld" | indent 2
function indent()
{
  local n=$1
  local spaces=$(printf '%*s' $((n * 2)) '')
  sed "s/^/$spaces/"
}

# Wrap content with module declaration
# Usage: wrap-module MODULE_NAME CONTENT
# Example: wrap-module MyModule "VERSION = \"1.0.0\""
function wrap-module()
{
  local module_name=$1
  local content=$2

  echo "module $module_name"
  echo "$content" | indent 1
  echo "end"
}

# Wrap content with multiple module declarations (from innermost to outermost)
# Usage: wrap-modules CONTENT MODULE_NAMES_ARRAY
# Example: wrap-modules "VERSION = \"1.0.0\"" module_names
function wrap-modules()
{
  local content=$1
  local array_name=$2

  # Use (P) flag for indirect parameter expansion (zsh way)
  local -a names
  names=("${(@P)array_name}")

  # Wrap from innermost to outermost module
  for ((i=${#names[@]}-1; i>=0; i--)); do
    content=$(wrap-module "${names[$i+1]}" "$content")
  done

  echo "$content"
}

# Generate cron schedule expression from directory path and current time
# Usage: cron-schedule
# Output: '16 8 * * *' (minute: 1-59, hour: 1-23)
function cron-schedule()
{
  # Use full PWD and current timestamp for uniqueness
  local input="${PWD}:$(date +%s)"

  # Calculate hash using SHA256 (via openssl for portability)
  local hash=$(echo -n "$input" | openssl sha256 -r | cut -d' ' -f1)

  # Convert hash to minute (1-59) and hour (1-23), excluding 0
  local minute=$((0x${hash:0:8} % 59 + 1))
  local hour=$((0x${hash:8:8} % 23 + 1))

  # Output cron expression
  echo "'$minute $hour * * *'"
}
