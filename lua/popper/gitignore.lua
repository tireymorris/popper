local M = {}

local function gitignore_to_lua_pattern(pattern)
  local negated = false
  if pattern:sub(1, 1) == "!" then
    negated = true
    pattern = pattern:sub(2)
  end

  local is_dir = pattern:sub(-1) == "/"
  if is_dir then
    pattern = pattern:sub(1, -2)
  end

  -- Check for recursive patterns starting with **/
  local is_recursive = pattern:sub(1, 3) == "**/"
  if is_recursive then
    pattern = pattern:sub(4)
  end

  -- Temporarily replace ** with placeholder
  pattern = pattern:gsub("%*%*", "\x01")

  -- Escape Lua magic characters (but not * since we handle it)
  pattern = pattern:gsub("([%%%.%+%-%?%[%]%^%$%(%)])", "%%%1")

  -- Convert * to [^/]* (match anything except /)
  pattern = pattern:gsub("%*", "[^/]*")

  -- Restore ** as .* (match anything including /)
  pattern = pattern:gsub("\x01", ".*")

  return pattern, negated, is_dir, is_recursive
end

function M.parse_gitignore(path)
  local patterns = {}
  local f = io.open(path, "r")
  if not f then
    return patterns
  end

  for line in f:lines() do
    if line ~= "" and not line:match("^%s*#") then
      local lua_pattern, negated, is_dir, is_recursive = gitignore_to_lua_pattern(line)
      table.insert(patterns, { pattern = lua_pattern, negated = negated, is_dir = is_dir, is_recursive = is_recursive })
    end
  end
  f:close()

  return patterns
end

function M.is_ignored(file_path, patterns, base_dir)
  -- Normalize the file path relative to base_dir
  local rel_path = file_path
  if base_dir and file_path:sub(1, #base_dir) == base_dir then
    rel_path = file_path:sub(#base_dir + 1)
    -- Strip leading slash
    if rel_path:sub(1, 1) == "/" then
      rel_path = rel_path:sub(2)
    end
  end

  local ignored = false
  for _, entry in ipairs(patterns) do
    local matched = false
    if entry.is_recursive then
      -- Recursive pattern: match pattern anywhere in the path as a path component
      -- **/vendor should match vendor, src/vendor, a/b/c/vendor
      local start_pat = "^" .. entry.pattern .. "(/.*)$"
      local exact_pat = "^" .. entry.pattern .. "$"
      local anywhere_pat = ".*/" .. entry.pattern .. "(/.*)$"
      local anywhere_exact = ".*/" .. entry.pattern .. "$"
      if string.match(rel_path, start_pat) or string.match(rel_path, exact_pat) or string.match(rel_path, anywhere_pat) or string.match(rel_path, anywhere_exact) then
        matched = true
      end
    elseif entry.is_dir then
      -- Directory pattern: match if path contains /dirname/ or starts with dirname/
      local dir_pat = "^" .. entry.pattern .. "/"
      local anywhere_pat = ".*/" .. entry.pattern .. "/"
      if string.match(rel_path, dir_pat) or string.match(rel_path, anywhere_pat) then
        matched = true
      end
    else
      -- File pattern: match at the end of the path
      -- Try matching the full relative path and just the filename
      local full_pat = entry.pattern .. "$"
      local filename = rel_path:match("([^/]+)$")
      local filename_pat = "^" .. entry.pattern .. "$"
      if string.match(rel_path, full_pat) or (filename and string.match(filename, filename_pat)) then
        matched = true
      end
    end

    if matched then
      if entry.negated then
        ignored = false
      else
        ignored = true
      end
    end
  end

  return ignored
end

return M
