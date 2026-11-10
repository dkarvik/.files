local script = [=[
set -euo pipefail
umask 077
root=$1
host=$2
owner=$3
name=$4
ref=$5
ttl=$6
repo="$root/repos/$host/$owner/$name"
trees="$root/trees/$host/$owner/$name"
base="$root/git_cache/$host/$owner/$name"
mkdir -p "$base" "$(dirname "$repo")" "$trees"
exec 9>"$base/lock"
flock -w 300 9 || { echo 'timed out waiting for repository lock' >&2; exit 1; }
tmp=''
cleanup() { if [ -n "$tmp" ]; then rm -rf -- "$tmp"; fi; }
trap cleanup EXIT
trap 'exit 124' TERM INT
export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_ATTR_NOSYSTEM=1
url="https://$host/$owner/$name.git"
if [ ! -e "$repo" ] && [ ! -L "$repo" ]; then
  tmp=$(mktemp -d "$(dirname "$repo")/.git-cache-clone.XXXXXXXX")
  git clone --quiet --mirror -- "$url" "$tmp/repo.git"
  mv -T -n -- "$tmp/repo.git" "$repo"
  if [ -e "$tmp/repo.git" ]; then echo 'repository cache appeared during clone; retry' >&2; exit 1; fi
  rm -rf -- "$tmp"
  tmp=''
fi
if [ -L "$repo" ] || [ ! -d "$repo" ]; then echo 'invalid repository cache path' >&2; exit 1; fi
bare=$(git -C "$repo" rev-parse --is-bare-repository) || { echo 'invalid repository cache' >&2; exit 1; }
if [ "$bare" = true ]; then
  [ -f "$repo/HEAD" ] && [ -d "$repo/objects" ] || { echo 'invalid bare repository cache' >&2; exit 1; }
  branches=refs/heads
elif [ "$bare" = false ] && [ -d "$repo/.git" ] && [ ! -L "$repo/.git" ]; then
  branches=refs/remotes/origin
else
  echo 'invalid legacy repository cache' >&2; exit 1
fi
origin=$(git -C "$repo" config --local --get remote.origin.url) || { echo 'repository cache has no origin' >&2; exit 1; }
if [ "$origin" != "$url" ] && [ "$origin" != "${url%.git}" ]; then echo 'repository cache origin does not match requested repository' >&2; exit 1; fi
now=$(date +%s)
last=''
if [ -f "$base/refreshed" ] && [ -f "$base/default" ]; then
  IFS= read -r last < "$base/refreshed" || true
fi
if [[ ! "$last" =~ ^[0-9]{1,12}$ ]] || (( now < last || now - last >= ttl )); then
  rm -f -- "$base/refreshed"
  observed=$(date +%s)
  head_info=$(git -C "$repo" ls-remote --symref origin HEAD)
  head_oid=$(printf '%s\n' "$head_info" | awk '$2 == "HEAD" && $1 != "ref:" {print $1}')
  head_ref=$(printf '%s\n' "$head_info" | awk '$1 == "ref:" && $3 == "HEAD" {print $2}')
  if [[ ! "$head_oid" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]]; then
    echo 'could not determine remote HEAD' >&2; exit 1
  fi
  git -C "$repo" fetch --quiet --atomic --prune --no-tags origin "+refs/heads/*:$branches/*" '+refs/tags/*:refs/tags/*'
  if [ -n "$head_ref" ]; then
    case "$head_ref" in refs/heads/*) ;; *) echo 'remote HEAD is not a branch' >&2; exit 1 ;; esac
    default="$branches/${head_ref#refs/heads/}"
    actual=$(git -C "$repo" rev-parse --verify --quiet "$default^{object}") || { echo 'remote HEAD branch missing after refresh' >&2; exit 1; }
    if [ "$actual" != "$head_oid" ]; then echo 'remote HEAD changed during refresh; retry' >&2; exit 1; fi
  else
    git -C "$repo" cat-file -e "$head_oid^{commit}" || { echo 'remote HEAD commit missing after refresh' >&2; exit 1; }
    default=$head_oid
  fi
  printf '%s\n' "$default" > "$base/default.tmp"
  mv -f -- "$base/default.tmp" "$base/default"
  printf '%s\n' "$observed" > "$base/refreshed.tmp"
  mv -f -- "$base/refreshed.tmp" "$base/refreshed"
fi
IFS= read -r default < "$base/default"
if [ "$bare" = true ]; then
  if [[ "$default" == refs/heads/* ]]; then
    git -C "$repo" symbolic-ref HEAD "$default"
  else
    git -C "$repo" update-ref --no-deref HEAD "$default"
  fi
elif [[ "$default" == refs/remotes/origin/* ]]; then
  git -C "$repo" symbolic-ref refs/remotes/origin/HEAD "$default"
fi
if [ -z "$ref" ]; then
  ref=$default
  candidates=("$ref")
elif [[ "$ref" =~ ^([0-9a-fA-F]{40}|[0-9a-fA-F]{64})$ ]]; then
  candidates=("$ref")
elif [[ "$ref" == refs/heads/* || "$ref" == refs/tags/* ]]; then
  git check-ref-format "$ref" >/dev/null || { echo 'invalid ref' >&2; exit 1; }
  if [[ "$ref" == refs/heads/* ]]; then
    candidates=("$branches/${ref#refs/heads/}")
  else
    candidates=("$ref")
  fi
else
  git check-ref-format "refs/heads/$ref" >/dev/null || { echo 'invalid ref' >&2; exit 1; }
  candidates=("$branches/$ref" "refs/tags/$ref")
fi
commit=''
for candidate in "${candidates[@]}"; do
  if commit=$(git -C "$repo" rev-parse --verify --quiet "$candidate^{commit}"); then break; fi
  commit=''
done
if [ -z "$commit" ]; then echo "revision not found: $ref" >&2; exit 1; fi
valid_snapshot() {
  local tree=$1 marker=$2 contents links
  [ ! -L "$tree" ] && [ -d "$tree" ] && [ ! -L "$marker" ] && [ -f "$marker" ] || return 1
  contents=$(cat -- "$marker") && [ "$contents" = "$commit" ] || return 1
  links=$(find -P "$tree" -type l -print -quit) && [ -z "$links" ]
}
snapshot="$trees/$commit"
marker="$trees/.$commit.complete"
if ! valid_snapshot "$snapshot" "$marker"; then
  snapshots="$base/snapshots"
  mkdir -p -- "$snapshots"
  published="$snapshots/$commit"
  snapshot="$published/tree"
  marker="$published/complete"
  if [ -e "$published" ] || [ -L "$published" ]; then
    if [ -L "$published" ] || ! valid_snapshot "$snapshot" "$marker"; then
      echo 'invalid safe snapshot; preserving it' >&2; exit 1
    fi
  else
    tmp=$(mktemp -d "$snapshots/.git-cache-tree.XXXXXXXX")
    mkdir -- "$tmp/tree"
    GIT_INDEX_FILE="$tmp/index" git -C "$repo" read-tree "$commit"
    GIT_INDEX_FILE="$tmp/index" git -C "$repo" --work-tree="$tmp/tree" checkout-index --all --force
    find -P "$tmp/tree" -type l -delete
    rm -f -- "$tmp/index" "$tmp/index.lock"
    printf '%s\n' "$commit" > "$tmp/complete"
    mv -T -n -- "$tmp" "$published"
    if [ -e "$tmp" ]; then echo 'snapshot appeared during checkout; retry' >&2; exit 1; fi
    tmp=''
  fi
fi
printf '%s\n%s\n%s\n' "$repo" "$snapshot" "$commit"
]=]

local function failure(message)
  return { llm_output = "error: " .. tostring(message), is_error = true }
end

local function valid_host(host)
  if #host > 253 or host:find("[^a-z0-9.%-]") or host:find("..", 1, true) then return false end
  for label in host:gmatch("[^.]+") do
    if #label > 63 or not label:match("^[a-z0-9]") or not label:match("[a-z0-9]$") then return false end
  end
  return host:sub(1, 1) ~= "." and host:sub(-1) ~= "." and host ~= ""
end

local function text(value)
  if type(value) == "table" then return table.concat(value, "\n") end
  return value or ""
end

maki.api.register_tool({
  name = "git_cache",
  permission = "run",
  kind = "search",
  timeout = 600,
  description = "Cache an HTTPS Git repository and return its clone path, revision-pinned snapshot path, and commit. The clone may be a legacy non-bare repository or a bare mirror. Use native read, glob, and grep on the snapshot; for git commands on the clone, explicitly use the returned commit rather than HEAD. Refresh remote branches, tags, and default HEAD when the persistent TTL expires; refresh errors are reported rather than serving stale refs. Snapshots exclude submodule contents and all symlinks. Snapshots are writable shared cache data, not enforced read-only: do not modify them, execute their contents, or trust them as a security boundary. Copy files elsewhere before editing; other local processes can alter cached contents.",
  schema = {
    type = "object",
    properties = {
      repository = { type = "string", description = "Repository in owner/repository form." },
      host = { type = "string", description = "HTTPS Git hostname; defaults to github.com." },
      ref = { type = "string", description = "Branch, tag, refs/heads/... or refs/tags/... name, or full commit hash; defaults to remote HEAD. Branches take precedence over tags." },
      ttl_seconds = { type = "integer", description = "Maximum age of the last successful refresh in seconds; default 3600, 0 forces a refresh." },
    },
    required = { "repository" },
  },
  handler = function(input)
    local repository = input.repository
    if type(repository) ~= "string" or #repository > 255 then return failure("repository must be owner/repository") end
    local owner, name = repository:match("^([%w_][%w_.%-]*)/([%w_][%w_.%-]*)$")
    if not owner or #owner > 100 or #name > 100 then return failure("repository must be owner/repository with safe path components") end
    local host = input.host == nil and "github.com" or input.host
    if type(host) ~= "string" then return failure("host must be a hostname") end
    host = host:lower()
    if not valid_host(host) then return failure("host must be a hostname without a port or URL") end
    local ref = input.ref
    if ref ~= nil and (type(ref) ~= "string" or #ref == 0 or #ref > 255 or not ref:match("^[%w_./%-]+$") or ref:sub(1, 1) == "-") then
      return failure("ref must be a branch, tag, or full commit hash")
    end
    local ttl = input.ttl_seconds
    if ttl == nil then ttl = 3600 end
    if type(ttl) ~= "number" or ttl ~= ttl or ttl < 0 or ttl > 315360000 or ttl % 1 ~= 0 then
      return failure("ttl_seconds must be an integer between 0 and 315360000")
    end
    local state = maki.env.state_dir()
    if not state then return failure("could not determine Maki state directory") end
    local root = maki.fs.joinpath(state, "librarian")
    local id, start_err = maki.fn.jobstart({ "timeout", "--kill-after=10s", "510s", "bash", "-c", script, "git_cache", root, host, owner, name, ref or "", tostring(ttl) }, { scope = "task", tail = 100, max_line_bytes = 4096 })
    if not id then return failure("could not start cache process: " .. tostring(start_err)) end
    local result, wait_err = maki.fn.jobwait(id, 540000)
    if not result then
      maki.fn.jobstop(id)
      return failure("cache process failed or timed out: " .. tostring(wait_err))
    end
    if result.exit_code ~= 0 then
      local detail = text(result.stderr)
      if detail == "" then detail = text(result.stdout) end
      return failure("cache process failed (exit " .. tostring(result.exit_code) .. "): " .. detail:sub(1, 8192))
    end
    local repo, snapshot, commit = text(result.stdout):match("^([^\n]+)\n([^\n]+)\n([0-9a-f]+)%s*$")
    if not repo or (#commit ~= 40 and #commit ~= 64) then return failure("cache process returned invalid output") end
    return { llm_output = "clone_path: " .. repo .. "\nsnapshot_path: " .. snapshot .. "\ncommit: " .. commit }
  end,
})
