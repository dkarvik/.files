local core = require("librarian.init")
local util = require("librarian.util")

local function run(input)
  if maki.fn.executable("gh") ~= 1 then return nil, "gh is not installed" end
  local limit = util.clamp(input.limit, 1, 50, 20)

  if input.action == "search_code" then
    if type(input.query) ~= "string" or input.query == "" then return nil, "query is required for search_code" end
    return util.run({ "gh", "search", "code", input.query, "--limit", tostring(limit) }, { timeout_ms = 60000 })
  end
  if input.action == "search_repos" then
    if type(input.query) ~= "string" or input.query == "" then return nil, "query is required for search_repos" end
    return util.run({ "gh", "search", "repos", input.query, "--limit", tostring(limit) }, { timeout_ms = 60000 })
  end

  local owner, name, err = util.repository_parts(input.repository)
  if not owner then return nil, err end
  local repository = owner .. "/" .. name
  if input.action == "repo" then
    return util.run({ "gh", "repo", "view", repository, "--json", "nameWithOwner,description,defaultBranchRef,url,homepageUrl,primaryLanguage" }, { timeout_ms = 30000 })
  end
  if input.action == "issue" then
    if not input.number then return nil, "number is required for issue" end
    return util.run({ "gh", "issue", "view", tostring(input.number), "--repo", repository, "--comments" }, { timeout_ms = 60000 })
  end
  if input.action == "pr" then
    if not input.number then return nil, "number is required for pr" end
    return util.run({ "gh", "pr", "view", tostring(input.number), "--repo", repository, "--comments" }, { timeout_ms = 60000 })
  end
  if input.action == "release" then
    local arguments = { "gh", "release", "view", "--repo", repository }
    if input.tag and input.tag ~= "" then table.insert(arguments, 4, input.tag) end
    return util.run(arguments, { timeout_ms = 60000 })
  end
  return nil, "unsupported action"
end

core.register_extension({
  name = "librarian_github",
  description = "Search and inspect GitHub through the authenticated gh CLI. This is read-only discovery for repositories, code, issues, pull requests, and releases.",
  schema = {
    type = "object",
    properties = {
      action = { type = "string", enum = { "search_code", "search_repos", "repo", "issue", "pr", "release" }, description = "GitHub read operation." },
      query = { type = "string", description = "Search query for search_code or search_repos." },
      repository = { type = "string", description = "Repository as owner/repository for repo, issue, pr, or release." },
      number = { type = "integer", description = "Issue or pull-request number." },
      tag = { type = "string", description = "Release tag; omit for the latest release." },
      limit = { type = "integer", description = "Result cap; defaults to 20." },
    },
    required = { "action" },
  },
  instructions = "Use GitHub discovery to locate likely repositories and context. Follow source-code leads with the cached Git extension before making source-behavior claims.",
  repository = function(input)
    if type(input.repository) ~= "string" or input.repository == "" then return nil end
    return "github.com/" .. input.repository
  end,
  handler = function(input)
    local output, err = run(input)
    if not output then return nil, err end
    return util.limit_text(output)
  end,
})
