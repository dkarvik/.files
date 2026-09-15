local M = {}

local MAX_OUTPUT_BYTES = 24 * 1024

local function text(value)
  if type(value) == "table" then return table.concat(value, "\n") end
  return value or ""
end

local function includes(values, value)
  for _, candidate in ipairs(values or {}) do
    if candidate == value then return true end
  end
  return false
end

function M.run(argv, opts)
  opts = opts or {}
  local ok, job_or_err = pcall(maki.fn.jobstart, argv, {
    cwd = opts.cwd,
    scope = "task",
    tail = 1024,
  })
  if not ok then return nil, tostring(job_or_err) end

  local result = maki.fn.jobwait(job_or_err, opts.timeout_ms or 60000)
  if not result then return nil, "command timed out" end

  local stdout = text(result.stdout)
  local stderr = text(result.stderr)
  if result.exit_code ~= 0 and not includes(opts.ok_codes, result.exit_code) then
    local detail = stderr ~= "" and stderr or stdout
    return nil, "command failed (exit " .. tostring(result.exit_code) .. "): " .. M.limit_text(detail)
  end
  return stdout, nil, result.exit_code
end

function M.limit_text(value, max_bytes)
  local limit = max_bytes or MAX_OUTPUT_BYTES
  if #value <= limit then return value end
  return value:sub(1, limit) .. "\n[output truncated]"
end

function M.lines(value)
  local lines = {}
  value = value:gsub("\r\n", "\n")
  if value == "" then return lines end
  for line in (value .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

function M.take_lines(value, limit)
  local lines = M.lines(value)
  if #lines <= limit then return table.concat(lines, "\n") end
  local selected = {}
  for index = 1, limit do selected[index] = lines[index] end
  selected[#selected + 1] = "[output truncated]"
  return table.concat(selected, "\n")
end

function M.number_lines(value, first, last)
  local lines = M.lines(value)
  local start = math.max(1, math.floor(tonumber(first) or 1))
  local finish = math.min(#lines, math.floor(tonumber(last) or (start + 199)))
  if start > #lines or finish < start then return nil, "requested line range is outside the file" end

  local numbered = {}
  for index = start, finish do
    numbered[#numbered + 1] = string.format("%d: %s", index, lines[index])
  end
  return table.concat(numbered, "\n"), start, finish
end

function M.cache_root()
  local home = maki.uv.os_homedir()
  if not home then return nil, "could not determine home directory" end
  local xdg = maki.uv.os_getenv("XDG_CACHE_HOME")
  if xdg and xdg:sub(1, 1) == "/" then
    return maki.fs.joinpath(xdg, "maki", "librarian", "repos")
  end
  return maki.fs.joinpath(home, ".cache", "maki", "librarian", "repos")
end

function M.repository_parts(repository)
  if type(repository) ~= "string" then return nil, nil, "repository is required" end
  local owner, name = repository:match("^([%w%._%-]+)/([%w%._%-]+)$")
  if not owner or not name then return nil, nil, "repository must be owner/repository" end
  return owner, name
end

function M.valid_host(host)
  return type(host) == "string" and host:match("^[%w%.%-]+$") ~= nil
end

function M.valid_ref(ref)
  return ref == nil or (type(ref) == "string" and ref:match("^[%w%._/%-]+$") ~= nil)
end

function M.valid_path(path)
  if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" or path:find("//", 1, true) then return false end
  for part in path:gmatch("[^/]+") do
    if part == "." or part == ".." or not part:match("^[%w%._%-]+$") then return false end
  end
  return true
end

function M.file_url(path)
  return "file://" .. path:gsub(" ", "%%20")
end

function M.repository_url(host, repository)
  return "https://" .. host .. "/" .. repository
end

function M.source_url(host, repository, revision, path, start_line, end_line)
  local url
  if host == "github.com" then
    url = M.repository_url(host, repository) .. "/blob/" .. revision .. "/" .. path
  else
    url = M.repository_url(host, repository) .. "/src/commit/" .. revision .. "/" .. path
  end
  if start_line then
    url = url .. "#L" .. tostring(start_line)
    if end_line and end_line ~= start_line then url = url .. "-L" .. tostring(end_line) end
  end
  return url
end

function M.clamp(value, minimum, maximum, fallback)
  local number = tonumber(value)
  if not number then return fallback end
  return math.max(minimum, math.min(maximum, math.floor(number)))
end

return M
