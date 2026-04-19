local M = {}

function M.parse_gitignore(path)
  local patterns = {}
  local f = io.open(path, "r")
  if not f then
    return patterns
  end

  for line in f:lines() do
    -- Skip empty lines and comments
    if line ~= "" and not line:match("^%s*#") then
      table.insert(patterns, line)
    end
  end
  f:close()

  return patterns
end

return M
