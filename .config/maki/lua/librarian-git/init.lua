local core = require("librarian.init")
local util = require("librarian.util")

local FETCH_THROTTLE_SECONDS = 120

local fetch_state = {}
local materialized = {}

local function cache_path(repository, host)
  local owner, name, err = util.repository_parts(repository)
  if not owner then return nil, err end
  host = host or "github.com"
  if not util.valid_host(host) then return nil, "host must be a hostname" end

  local root, root_err = util.cache_root()
  if not root then return nil, root_err end
  return maki.fs.joinpath(root, host, owner, name)
end

local function source_url(host, repository, revision, path, start_line, end_line)
  local base = "https://" .. host .. "/" .. repository
  local url = host == "github.com"
    and base .. "/blob/" .. revision .. "/" .. path
    or base .. "/src/commit/" .. revision .. "/" .. path
  url = url .. "#L" .. tostring(start_line)
  if end_line ~= start_line then url = url .. "-L" .. tostring(end_line) end
  return url
end

local function file_url(path)
  return "file://" .. path:gsub(" ", "%%20")
end

local function ensure_clone(path, host, repository)
  local git_dir = maki.fs.joinpath(path, ".git")
  local meta = maki.fs.metadata(git_dir)
  if meta and meta.is_dir then return nil end
  local parent = maki.fs.dirname(path)
  local ok, mkdir_err = maki.fs.mkdir(parent, { parents = true })
  if not ok then return "could not create cache directory: " .. mkdir_err end
  local _, clone_err = util.run({ "git", "clone", "--filter=blob:none", "--no-checkout", "https://" .. host .. "/" .. repository .. ".git", path }, { timeout_ms = 120000 })
  if clone_err then
    meta = maki.fs.metadata(git_dir)
    if meta and meta.is_dir then return nil end
    return clone_err
  end
  return nil
end

local function resolve_sha(path, ref)
  local candidates = { ref }
  if ref == "origin/HEAD" then
    candidates[#candidates + 1] = "refs/remotes/origin/HEAD"
  else
    candidates[#candidates + 1] = "refs/remotes/origin/" .. ref
    candidates[#candidates + 1] = "refs/tags/" .. ref
  end
  for _, candidate in ipairs(candidates) do
    local sha = util.run({ "git", "-C", path, "rev-parse", "--verify", "--quiet", candidate .. "^{commit}" }, { timeout_ms = 10000, ok_codes = { 1 } })
    if sha and sha ~= "" then return sha:gsub("%s+$", "") end
  end
  return nil
end

local function resolve_revision(repository, host, ref)
  if not util.valid_ref(ref) then return nil, "ref contains unsupported characters" end
  local path, path_err = cache_path(repository, host)
  if not path then return nil, path_err end
  host = host or "github.com"

  local clone_err = ensure_clone(path, host, repository)
  if clone_err then return nil, clone_err end

  local target = ref or "origin/HEAD"
  local revision = resolve_sha(path, target)
  if not revision then
    local last = fetch_state[path] or 0
    if os.time() - last < FETCH_THROTTLE_SECONDS then
      return nil, "revision not found: " .. (ref or "default branch") .. "; use the `refs` action to list available branches and tags"
    end
    local _, fetch_err = util.run({ "git", "-C", path, "fetch", "--quiet", "--prune", "--tags", "origin" }, { timeout_ms = 120000 })
    if fetch_err then return nil, fetch_err end
    fetch_state[path] = os.time()
    revision = resolve_sha(path, target)
    if not revision then return nil, "revision not found: " .. (ref or "default branch") .. "; use the `refs` action to list available branches and tags" end
  end

  return { host = host, path = path, repository = repository, revision = revision }
end

local function ensure_blobs(repo)
  if materialized[repo.path] == repo.revision then return nil end
  local _, err = util.run({
    "git", "-C", repo.path,
    "-c", "remote.origin.promisor=false",
    "-c", "remote.origin.partialclonefilter=",
    "fetch", "--quiet", "--no-write-fetch-head", "origin", repo.revision,
  }, { timeout_ms = 180000 })
  if err then return err end
  materialized[repo.path] = repo.revision
  return nil
end

local function materialize_file(repo, relpath)
  local target = maki.fs.joinpath(repo.path, relpath)
  local meta = maki.fs.metadata(target)
  if meta and meta.is_file then return target end
  local contents = util.run({ "git", "-C", repo.path, "show", repo.revision .. ":" .. relpath }, { timeout_ms = 30000 })
  if not contents then return nil end
  local parent = maki.fs.dirname(target)
  local ok = maki.fs.mkdir(parent, { parents = true })
  if not ok then return nil end
  local written = maki.fs.write(target, contents)
  if not written then return nil end
  return target
end

core.register_extension({
  name = "librarian_cached_git",
  description = "Inspect a cached read-only Git repository. Use it for source code, history, and precise file citations. It maintains a persistent XDG cache and returns permanent web URLs plus file:// cache URLs.",
  schema = {
    type = "object",
    properties = {
      repository = { type = "string", description = "Repository as owner/repository." },
      host = { type = "string", description = "Git host; defaults to github.com." },
      ref = { type = "string", description = "Optional branch, tag, or revision; defaults to the remote default branch. Pass the version branch or tag when the task names one." },
      action = { type = "string", enum = { "refs", "files", "read", "search", "log" }, description = "Inspection operation." },
      path = { type = "string", description = "Repository-relative path, required for read." },
      query = { type = "string", description = "Literal text for search, or an optional path filter for log." },
      start_line = { type = "integer", description = "First line for read; defaults to 1." },
      end_line = { type = "integer", description = "Last line for read; defaults to start_line + 199." },
      limit = { type = "integer", description = "Result cap; defaults to 50." },
    },
    required = { "repository", "action" },
  },
  instructions = [[Cached Git is the source of truth for source-code claims. Pass `ref` when the task names a version or branch; when unsure which refs exist, list them with the `refs` action first. If a read fails because the path does not exist, discover the real path with `files` or `search` instead of retrying the same call. Never retry a failing call unchanged. Cite sources with the returned `Source URL` written on its own line; `Cache URL` is the on-disk alternative.]],
  repository = function(input)
    if type(input.repository) ~= "string" or input.repository == "" then return nil end
    return (input.host or "github.com") .. "/" .. input.repository
  end,
  handler = function(input)
    local repo, repo_err = resolve_revision(input.repository, input.host, input.ref)
    if not repo then return nil, repo_err end
    local root_url = "https://" .. repo.host .. "/" .. repo.repository
    local revision = repo.revision
    local limit = util.clamp(input.limit, 1, 100, 50)

    if input.action == "refs" then
      local branches, branches_err = util.run({ "git", "-C", repo.path, "branch", "-r", "--no-color" }, { timeout_ms = 30000 })
      if not branches then return nil, branches_err end
      local tags, tags_err = util.run({ "git", "-C", repo.path, "tag" }, { timeout_ms = 30000 })
      if not tags then return nil, tags_err end
      return "Repository URL: " .. root_url .. "\nBranches:\n" .. util.take_lines(branches, limit) .. "\nTags:\n" .. util.take_lines(tags, limit)
    end

    if input.action == "files" then
      local files, err = util.run({ "git", "-C", repo.path, "ls-tree", "-r", "--name-only", revision }, { timeout_ms = 30000 })
      if not files then return nil, err end
      return "Repository URL: " .. root_url .. "\nCache URL: " .. file_url(repo.path) .. "\nRevision: " .. revision .. "\nFiles:\n" .. util.take_lines(files, limit)
    end

    if input.action == "read" then
      if not util.valid_path(input.path) then return nil, "path must be a safe repository-relative path" end
      local contents, err = util.run({ "git", "-C", repo.path, "show", revision .. ":" .. input.path }, { timeout_ms = 30000 })
      if not contents then return nil, err end
      local numbered, start, finish = util.number_lines(contents, input.start_line, input.end_line)
      if not numbered then return nil, finish end
      local output = "Source URL: " .. source_url(repo.host, repo.repository, revision, input.path, start, finish)
      local cache_file = materialize_file(repo, input.path)
      if cache_file then output = output .. "\nCache URL: " .. file_url(cache_file) end
      return output .. "\nRevision: " .. revision .. "\nLocation: " .. input.path .. ":" .. start .. "-" .. finish .. "\n" .. numbered
    end

    if input.action == "search" then
      if type(input.query) ~= "string" or input.query == "" then return nil, "query is required for search" end
      local blob_err = ensure_blobs(repo)
      if blob_err then return nil, blob_err end
      local hits, err = util.run({ "git", "-C", repo.path, "grep", "-n", "-I", "-F", "--", input.query, revision }, { timeout_ms = 30000, ok_codes = { 1 } })
      if not hits and err then return nil, err end
      if hits == "" then return "No matches in " .. root_url .. " at " .. revision end
      local formatted = {}
      for _, hit in ipairs(util.lines(util.take_lines(hits, limit))) do
        local path, line, text = hit:match("^[^:]+:([^:]+):(%d+):(.*)$")
        if path then
          local number = tonumber(line)
          formatted[#formatted + 1] = source_url(repo.host, repo.repository, revision, path, number, number) .. "\n" .. path .. ":" .. line .. ": " .. text
        end
      end
      return "Repository URL: " .. root_url .. "\nCache URL: " .. file_url(repo.path) .. "\nRevision: " .. revision .. "\nMatches:\n" .. table.concat(formatted, "\n")
    end

    if input.action == "log" then
      local arguments = { "git", "-C", repo.path, "log", "-n", tostring(limit), "--format=%H%x09%ad%x09%s", "--date=short", revision }
      if input.query and input.query ~= "" then
        if not util.valid_path(input.query) then return nil, "query path must be a safe repository-relative path" end
        arguments[#arguments + 1] = "--"
        arguments[#arguments + 1] = input.query
      end
      local commits, err = util.run(arguments, { timeout_ms = 30000 })
      if not commits then return nil, err end
      return "Repository URL: " .. root_url .. "\nCache URL: " .. file_url(repo.path) .. "\nRevision: " .. revision .. "\nCommits:\n" .. util.take_lines(commits, limit)
    end

    return nil, "unsupported action"
  end,
})
