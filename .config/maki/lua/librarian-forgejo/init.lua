local core = require("librarian.init")
local util = require("librarian.util")

local function repository_args(input)
  local owner, name, err = util.repository_parts(input.repository)
  if not owner then return nil, err end
  local host = input.host or "codeberg.org"
  if not util.valid_host(host) then return nil, "host must be a hostname" end
  return host, owner .. "/" .. name
end

local function run(input)
  if maki.fn.executable("fj") ~= 1 then return nil, "fj (forgejo-cli) is not installed" end
  local host, repository = repository_args(input)
  if not host then return nil, repository end

  if input.action == "repo" then return util.run({ "fj", "--host", host, "repo", "view", repository }, { timeout_ms = 30000 }) end
  if input.action == "readme" then return util.run({ "fj", "--host", host, "repo", "readme", repository }, { timeout_ms = 30000 }) end
  if input.action == "issues" then
    local arguments = { "fj", "--host", host, "issue", "search", "--repo", repository, "--state", input.state or "all" }
    if input.query and input.query ~= "" then arguments[#arguments + 1] = input.query end
    return util.run(arguments, { timeout_ms = 60000 })
  end
  if input.action == "issue" then
    if not input.number then return nil, "number is required for issue" end
    return util.run({ "fj", "--host", host, "issue", "view", repository .. "#" .. tostring(input.number) }, { timeout_ms = 60000 })
  end
  if input.action == "prs" then
    local arguments = { "fj", "--host", host, "pr", "search", "--repo", repository, "--state", input.state or "all" }
    if input.query and input.query ~= "" then arguments[#arguments + 1] = input.query end
    return util.run(arguments, { timeout_ms = 60000 })
  end
  if input.action == "pr" then
    if not input.number then return nil, "number is required for pr" end
    return util.run({ "fj", "--host", host, "pr", "view", repository .. "#" .. tostring(input.number) }, { timeout_ms = 60000 })
  end
  if input.action == "wiki" then
    if type(input.query) ~= "string" or input.query == "" then return nil, "query must name the wiki page" end
    return util.run({ "fj", "--host", host, "wiki", "view", "--repo", repository, input.query }, { timeout_ms = 60000 })
  end
  return nil, "unsupported action"
end

core.register_extension({
  name = "librarian_forgejo",
  description = "Inspect Forgejo through the installed fj command. This is a read-only wrapper for repository details, README files, issues, pull requests, and wiki pages.",
  schema = {
    type = "object",
    properties = {
      action = { type = "string", enum = { "repo", "readme", "issues", "issue", "prs", "pr", "wiki" }, description = "Forgejo read operation." },
      host = { type = "string", description = "Forgejo host; defaults to codeberg.org." },
      repository = { type = "string", description = "Repository as owner/repository." },
      query = { type = "string", description = "Text query for issues or pull requests, or a wiki page name." },
      number = { type = "integer", description = "Issue or pull-request number." },
      state = { type = "string", enum = { "open", "closed", "all" }, description = "Issue/pull-request state; defaults to all." },
    },
    required = { "action", "repository" },
  },
  instructions = "Use Forgejo discovery for repository metadata and discussion context. For source-code evidence, use the cached Git extension with the Forgejo host.",
  repository = function(input)
    if type(input.repository) ~= "string" or input.repository == "" then return nil end
    return (input.host or "codeberg.org") .. "/" .. input.repository
  end,
  handler = function(input)
    local output, err = run(input)
    if not output then return nil, err end
    return util.limit_text(output)
  end,
})
