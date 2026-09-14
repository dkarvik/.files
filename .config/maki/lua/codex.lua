local CODEX_BASE = "https://chatgpt.com/backend-api/codex"
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

local function show_modal(title, lines, footer)
  local buffer = maki.ui.buf()
  for _, line in ipairs(lines) do buffer:line(line) end
  local window = maki.ui.open_win(buffer, {
    title = title,
    width = "70%",
    height = math.min(#lines + 2, 20),
    footer = footer or { { "Any key", "close" } },
  })
  local key
  while true do
    local event = window:recv()
    if not event or event.type == "close" then break end
    if event.type == "key" then
      key = event.key
      break
    end
  end
  window:close()
  return key
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

local function iso_to_epoch(value)
  local year, month, day, hour, min, sec = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d):?(%d*)")
  if not year then return nil end
  local t = {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec) or 0,
  }
  local utc_offset = os.difftime(os.time(), os.time(os.date("!*t")))
  return os.time(t) - utc_offset
end

local function pretty_expiry(value)
  local timestamp = tonumber(value)
  if not timestamp or timestamp < 100000 then
    timestamp = iso_to_epoch(value)
  end
  if not timestamp then return tostring(value) end
  local remaining = timestamp - os.time()
  local date = os.date("%b %d %H:%M", timestamp)
  if remaining < 0 then return "expired (" .. date .. ")" end
  return "in " .. maki.ui.humantime(remaining) .. " (" .. date .. ")"
end

maki.api.register_command({
  name = "codex-reset",
  description = "Show available Codex usage-limit resets; press y to use one.",
  handler = function()
    local credits, err = reset_credits()
    if not credits then
      maki.ui.flash("Could not load Codex reset credits: " .. err)
      return
    end
    local available = {}
    for _, credit in ipairs(credits.credits or {}) do
      if credit.status == "available" and credit.reset_type == "codex_rate_limits" and credit.id then
        available[#available + 1] = credit
      end
    end
    table.sort(available, function(a, b)
      local ea = iso_to_epoch(a.expires_at or "") or 0
      local eb = iso_to_epoch(b.expires_at or "") or 0
      return ea < eb
    end)
    local lines = { "Codex resets: " .. tostring(credits.available_count or #available) .. " available" }
    if #available == 0 then
      lines[#lines + 1] = "Press any key to close."
    else
      local last_key
      for _, credit in ipairs(available) do
        local key = (credit.title or "Full reset") .. "\n" .. (credit.description or "")
        if key ~= last_key then
          last_key = key
          lines[#lines + 1] = credit.title or "Full reset"
          if credit.description then lines[#lines + 1] = credit.description end
        end
        lines[#lines + 1] = "- expires " .. (pretty_expiry(credit.expires_at) or tostring(credit.expires_at))
      end
    end
    local key = show_modal("Codex resets", lines, { { "y", "use next-expiring reset" }, { "Any key", "close" } })
    if key ~= "y" or #available == 0 then return end
    local outcome, consume_err = consume_reset(available[1].id)
    if not outcome then
      maki.ui.flash("Could not redeem Codex reset: " .. consume_err)
      return
    end
    local message = outcome.code == "reset" and "Codex usage limits reset." or outcome.code == "already_redeemed" and "This Codex reset was already redeemed." or outcome.code == "nothing_to_reset" and "Codex usage does not need a reset." or "No Codex reset was redeemed."
    if outcome.windows_reset ~= nil then message = message .. " Windows reset: " .. tostring(outcome.windows_reset) .. "." end
    maki.ui.flash(message)
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
