local CODEX_BASE = "https://chatgpt.com/backend-api/codex"
local CODEX_USAGE_URL = "https://chatgpt.com/backend-api/wham/usage"
local CODEX_RESET_CREDITS_URL = "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"

local function credentials()
  local state_dir = maki.env.state_dir()
  if not state_dir then return nil, "could not determine Maki state directory" end
  local text, err = maki.fs.read(maki.fs.joinpath(state_dir, "auth", "openai.json"))
  if not text then return nil, "could not read OpenAI authentication: " .. err end
  local auth, decode_err = maki.json.decode(text)
  if not auth or not auth.access or not auth.account_id then
    return nil, "OpenAI Codex authentication is unavailable: " .. (decode_err or "missing access token or account id")
  end
  return auth
end

local function describe_http_error(status, body)
  local decoded = maki.json.decode(body or "")
  local err = decoded and decoded.error
  if err and err.type == "usage_limit_reached" then
    local parts = { "Codex usage limit reached" }
    if err.resets_in_seconds then
      parts[#parts + 1] = "resets in " .. maki.ui.humantime(err.resets_in_seconds)
    end
    if err.resets_at then
      parts[#parts + 1] = "at " .. os.date("%Y-%m-%d %H:%M:%S %Z", err.resets_at)
    end
    parts[#parts + 1] = "check /usage or redeem a reset with /codex-reset"
    return table.concat(parts, "; ")
  end
  if err and err.message then
    local kind = err.type and (err.type .. ": ") or ""
    return "Codex request failed (HTTP " .. status .. "): " .. kind .. err.message
  end
  return "Codex request failed (HTTP " .. status .. ")"
end

local function request(path, body, timeout)
  local auth, auth_err = credentials()
  if not auth then return nil, auth_err end
  local encoded, encode_err = maki.json.encode(body)
  if not encoded then return nil, encode_err end
  local response, err = maki.net.request(CODEX_BASE .. path, {
    method = "POST",
    timeout = timeout or 120,
    headers = {
      ["Authorization"] = "Bearer " .. auth.access,
      ["chatgpt-account-id"] = auth.account_id,
      ["content-type"] = "application/json",
      ["accept"] = "text/event-stream",
      ["originator"] = "codex_cli_rs",
      ["User-Agent"] = "codex_cli_rs/0.0.0 (maki)",
    },
    body = encoded,
  })
  if not response then return nil, err end
  if response.status < 200 or response.status >= 300 then
    return nil, describe_http_error(response.status, response.body)
  end
  return response.body
end

local function show_modal(title, lines)
  local buffer = maki.ui.buf()
  for _, line in ipairs(lines) do buffer:line(line) end
  local window = maki.ui.open_win(buffer, {
    title = title,
    width = "70%",
    height = math.min(#lines + 2, 20),
    footer = { { "Any key", "close" } },
  })
  while true do
    local event = window:recv()
    if not event or event.type == "close" then break end
    if event.type == "key" and event.key ~= "enter" then break end
  end
  window:close()
end

local function codex_usage()
  local auth, auth_err = credentials()
  if not auth then return nil, auth_err end
  local response, err = maki.net.request(CODEX_USAGE_URL, {
    headers = {
      ["Authorization"] = "Bearer " .. auth.access,
      ["chatgpt-account-id"] = auth.account_id,
      ["accept"] = "application/json",
      ["originator"] = "codex_cli_rs",
      ["User-Agent"] = "codex_cli_rs/0.0.0 (maki)",
    },
  })
  if not response then return nil, err end
  if response.status < 200 or response.status >= 300 then
    return nil, "Codex usage request failed (HTTP " .. response.status .. "): " .. response.body
  end
  local usage, decode_err = maki.json.decode(response.body)
  if not usage then return nil, "could not parse Codex usage response: " .. decode_err end
  return usage
end

local function reset_credits()
  local auth, auth_err = credentials()
  if not auth then return nil, auth_err end
  local response, err = maki.net.request(CODEX_RESET_CREDITS_URL, {
    headers = {
      ["Authorization"] = "Bearer " .. auth.access,
      ["chatgpt-account-id"] = auth.account_id,
      ["accept"] = "application/json",
      ["originator"] = "codex_cli_rs",
      ["User-Agent"] = "codex_cli_rs/0.0.0 (maki)",
    },
  })
  if not response then return nil, err end
  if response.status < 200 or response.status >= 300 then
    return nil, describe_http_error(response.status, response.body)
  end
  local credits, decode_err = maki.json.decode(response.body)
  if not credits then return nil, "could not parse Codex reset credits response: " .. decode_err end
  return credits
end

local function redemption_id()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return template:gsub("[xy]", function(character)
    local value = math.random(0, 15)
    if character == "y" then value = value % 4 + 8 end
    return string.format("%x", value)
  end)
end

local function consume_reset(credit_id)
  local auth, auth_err = credentials()
  if not auth then return nil, auth_err end
  local body, encode_err = maki.json.encode({ credit_id = credit_id, redeem_request_id = redemption_id() })
  if not body then return nil, encode_err end
  local response, err = maki.net.request(CODEX_RESET_CREDITS_URL .. "/consume", {
    method = "POST",
    headers = {
      ["Authorization"] = "Bearer " .. auth.access,
      ["chatgpt-account-id"] = auth.account_id,
      ["content-type"] = "application/json",
      ["accept"] = "application/json",
      ["originator"] = "codex_cli_rs",
      ["User-Agent"] = "codex_cli_rs/0.0.0 (maki)",
    },
    body = body,
  })
  if not response then return nil, err end
  if response.status < 200 or response.status >= 300 then
    return nil, describe_http_error(response.status, response.body)
  end
  local outcome, decode_err = maki.json.decode(response.body)
  if not outcome then return nil, "could not parse Codex reset response: " .. decode_err end
  return outcome
end

local function sse_events(body)
  local events = {}
  for frame in (body .. "\n\n"):gmatch("(.-)\r?\n\r?\n") do
    local data = {}
    local event_type
    for line in frame:gmatch("[^\r\n]+") do
      if line:sub(1, 6) == "event:" then event_type = line:sub(7):match("^%s*(.-)%s*$") end
      if line:sub(1, 5) == "data:" then data[#data + 1] = line:sub(6):match("^%s?(.*)$") end
    end
    local raw = table.concat(data, "\n")
    if raw ~= "" and raw ~= "[DONE]" then
      local value = maki.json.decode(raw)
      if value then events[#events + 1] = { type = event_type, value = value } end
    end
  end
  return events
end

local function default_model()
  local auth, auth_err = credentials()
  if not auth then return nil, auth_err end
  local response, err = maki.net.request(CODEX_BASE .. "/models", {
    headers = {
      ["Authorization"] = "Bearer " .. auth.access,
      ["chatgpt-account-id"] = auth.account_id,
      ["accept"] = "application/json",
      ["originator"] = "codex_cli_rs",
      ["User-Agent"] = "codex_cli_rs/0.0.0 (maki)",
    },
  })
  if not response or response.status < 200 or response.status >= 300 then return "gpt-5.5" end
  local models = maki.json.decode(response.body)
  for _, model in ipairs((models or {}).models or {}) do
    if model.is_default then return model.slug or model.id or model.model end
  end
  local first = ((models or {}).models or {})[1]
  return first and (first.slug or first.id or first.model) or "gpt-5.5"
end

maki.api.register_command({
  name = "codex-usage",
  description = "Show Codex subscription limits, reset times, and available usage-limit resets.",
  handler = function()
    local usage, err = codex_usage()
    if not usage then
      maki.ui.flash("Could not load Codex usage: " .. err)
      return
    end
    local lines = { "Codex usage" }
    if usage.plan_type then lines[#lines + 1] = "Plan: " .. usage.plan_type end
    local function time_until(timestamp)
      return maki.ui.humantime(math.max(0, timestamp - os.time()))
    end
    local function add_window(label, window)
      if not window or window.used_percent == nil then return end
      local line = label .. ": " .. tostring(window.used_percent) .. "% used"
      if window.limit_window_seconds then line = line .. " / " .. math.ceil(window.limit_window_seconds / 60) .. " min" end
      if window.reset_at then line = line .. " / resets in " .. time_until(window.reset_at) .. " at " .. os.date("%Y-%m-%d %H:%M:%S %Z", window.reset_at) end
      lines[#lines + 1] = line
    end
    add_window("Primary limit", (usage.rate_limit or {}).primary_window)
    add_window("Secondary limit", (usage.rate_limit or {}).secondary_window)
    for _, item in ipairs(usage.additional_rate_limits or {}) do
      local limit = item.rate_limit or {}
      local label = item.limit_name or item.metered_feature or "Additional limit"
      add_window(label .. " primary", limit.primary_window)
      add_window(label .. " secondary", limit.secondary_window)
    end
    local resets = usage.rate_limit_reset_credits or {}
    if resets.available_count ~= nil then lines[#lines + 1] = "Usage limit resets: " .. tostring(resets.available_count) .. " available" end
    if #lines == 1 then lines[#lines + 1] = "No displayable usage limits returned." end
    show_modal("Codex usage", lines)
  end,
})

maki.api.register_command({
  name = "codex-redeem-reset",
  description = "Choose and confirm redemption of an available Codex usage-limit reset.",
  handler = function()
    local credits, err = reset_credits()
    if not credits then
      maki.ui.flash("Could not load Codex reset credits: " .. err)
      return
    end
    local options = {}
    for _, credit in ipairs(credits.credits or {}) do
      if credit.status == "available" and credit.reset_type == "codex_rate_limits" and credit.id then
        local detail = credit.description or "Reset current Codex usage limits."
        if credit.expires_at then detail = detail .. " Expires " .. credit.expires_at .. "." end
        options[#options + 1] = { label = credit.title or "Full reset", detail = detail, credit_id = credit.id }
      end
    end
    if #options == 0 then
      maki.ui.flash("No Codex usage-limit resets are available.")
      return
    end
    local ListPicker = require("maki.list_picker")
    local choice = ListPicker.open(options, { title = "Redeem Codex usage-limit reset", footer = { { "Enter", "select" }, { "Esc", "cancel" } } })
    if choice.type ~= "choice" then return end
    local selected = options[choice.index]
    local confirmation = ListPicker.open({ { label = "Redeem " .. selected.label, detail = "This consumes one reset and resets your current Codex usage limits." } }, { title = "Confirm reset redemption", footer = { { "Enter", "redeem" }, { "Esc", "cancel" } } })
    if confirmation.type ~= "choice" then return end
    local outcome, consume_err = consume_reset(selected.credit_id)
    if not outcome then
      maki.ui.flash("Could not redeem Codex reset: " .. consume_err)
      return
    end
    local message = outcome.code == "reset" and "Codex usage limits reset." or outcome.code == "already_redeemed" and "This Codex reset was already redeemed." or outcome.code == "nothing_to_reset" and "Codex usage does not need a reset." or "No Codex reset was redeemed."
    if outcome.windows_reset ~= nil then message = message .. " Windows reset: " .. tostring(outcome.windows_reset) .. "." end
    show_modal("Codex reset redemption", { message })
  end,
})

maki.api.register_tool({
  name = "codex_search",
  kind = "web",
  description = "Search the web using the configured ChatGPT Codex subscription. Use for current or source-backed information.",
  schema = {
    type = "object",
    properties = {
      queries = { type = "array", items = { type = "string" }, description = "One or more web-search queries." },
      search_context_size = { type = "string", enum = { "low", "medium", "high" }, description = "Web context amount; defaults to medium." },
      include = { type = "array", items = { type = "string", enum = { "file_search_call.results", "web_search_call.results", "web_search_call.action.sources", "message.input_image.image_url", "computer_call_output.output.image_url", "code_interpreter_call.outputs", "reasoning.encrypted_content", "message.output_text.logprobs" } }, description = "Optional extra response data. Omit unless the requested selector is useful; most web searches use web_search_call.results or web_search_call.action.sources." },
    },
    required = { "queries" },
  },
  timeout = 120,
  handler = function(input)
    if not input.queries or #input.queries == 0 then return { llm_output = "error: queries is required", is_error = true } end
    local model, model_err = default_model()
    if not model then return { llm_output = "error: " .. model_err, is_error = true } end
    local results = {}
    for _, query in ipairs(input.queries) do
      local payload = {
        model = model,
        instructions = "You are a concise web search assistant. Use web search, answer the query, and preserve source citations from annotations.",
        input = { { type = "message", role = "user", content = { { type = "input_text", text = query } } } },
        tools = { { type = "web_search", external_web_access = true, search_context_size = input.search_context_size or "medium" } },
        tool_choice = "required",
        parallel_tool_calls = true,
        store = false,
        stream = true,
      }
      if input.include and #input.include > 0 then payload.include = input.include end
      local body, err = request("/responses", payload)
      if not body then return { llm_output = "error: " .. err, is_error = true } end
      local text, citations = "", {}
      for _, event in ipairs(sse_events(body)) do
        local item = event.value.item
        if event.type == "response.output_text.delta" then text = text .. (event.value.delta or "") end
        if event.type == "response.output_item.done" and item and item.type == "message" then
          for _, part in ipairs(item.content or {}) do
            if part.type == "output_text" then
              text = part.text or text
              for _, citation in ipairs(part.annotations or {}) do
                if citation.type == "url_citation" and citation.url then citations[citation.url] = citation.title or citation.url end
              end
            end
          end
        end
      end
      local sources = {}
      for url, title in pairs(citations) do sources[#sources + 1] = "- " .. title .. ": " .. url end
      table.sort(sources)
      results[#results + 1] = "## " .. query .. "\n" .. text .. (#sources > 0 and "\n\nSources:\n" .. table.concat(sources, "\n") or "")
    end
    return { llm_output = table.concat(results, "\n\n"), format = "markdown" }
  end,
})

local function find_image(value)
  if type(value) ~= "table" then return nil end
  if value.type == "image_generation_call" and (value.result or value.b64_json) then return value end
  if value.item then
    local item = find_image(value.item)
    if item then return item end
  end
  for _, item in ipairs(value.output or {}) do
    local image = find_image(item)
    if image then return image end
  end
  if value.response then return find_image(value.response) end
end

maki.api.register_tool({
  name = "image_generation",
  kind = "image",
  description = "Generate or edit raster images through the ChatGPT Codex subscription. Saves the completed image under ~/.codex/generated_images/maki.",
  schema = {
    type = "object",
    properties = {
      prompt = { type = "string", description = "Image generation or editing prompt." },
      images = { type = "array", items = { type = "string" }, description = "Optional local image paths to edit or use as references." },
      output_format = { type = "string", enum = { "png", "jpeg", "webp" }, description = "Output format; defaults to png." },
      model = { type = "string", description = "Optional Codex model; defaults to gpt-5.5." },
    },
    required = { "prompt" },
  },
  timeout = 120,
  handler = function(input)
    local format = input.output_format or "png"
    local content = { { type = "input_text", text = input.prompt } }
    for _, path in ipairs(input.images or {}) do
      local bytes, err = maki.fs.read_bytes(path)
      if not bytes then return { llm_output = "error: could not read image " .. path .. ": " .. err, is_error = true } end
      content[#content + 1] = { type = "input_image", detail = "auto", image_url = "data:image/png;base64," .. maki.base64.encode(bytes) }
    end
    local body, err = request("/responses", {
      model = input.model or "gpt-5.5",
      instructions = "",
      input = { { role = "user", content = content } },
      tools = { { type = "image_generation", output_format = format } },
      tool_choice = { type = "image_generation" },
      parallel_tool_calls = false,
      store = false,
      stream = true,
    }, 120)
    if not body then return { llm_output = "error: " .. err, is_error = true } end
    local image
    for _, event in ipairs(sse_events(body)) do
      image = find_image(event.value) or image
    end
    if not image then return { llm_output = "error: Codex did not return an image", is_error = true } end
    local data = image.result or image.b64_json
    data = data:match("^data:[^;]+;base64,(.*)$") or data
    local id = image.id or "image"
    local extension = format == "jpeg" and "jpg" or format
    local directory = "~/.codex/generated_images/maki"
    local ok, mkdir_err = maki.fs.mkdir(directory, { parents = true })
    if not ok then return { llm_output = "error: could not create output directory: " .. mkdir_err, is_error = true } end
    local path = directory .. "/" .. id .. "." .. extension
    local write_ok, write_err = maki.fs.write(path, maki.base64.decode(data))
    if not write_ok then return { llm_output = "error: could not save image: " .. write_err, is_error = true } end
    return { llm_output = "Generated image saved to: " .. path, written_path = path, image = { media_type = "image/" .. format, data = data } }
  end,
})
