local init = require('init')

init.packadd("https://github.com/j-hui/fidget.nvim.git")

function LspStatus(...)
  local bufnr = vim.fn.winbufnr(vim.g.statusline_winid)
  return "[LSP" .. (#vim.lsp.get_clients({bufnr = bufnr}) > 0 and "+" or "-") .. "]"
end

vim.api.nvim_create_autocmd("User", {
  pattern = "Flags",
  callback = function()
    vim.fn.Hoist("buffer", LspStatus)
  end,
})

function _G.code_action_printer(code_action)
  vim.notify(vim.inspect(code_action))
  return true
end

function _G.filter_code_action(name)
  return function(code_action)
    return code_action.command.command == name
  end
end

local function set_repeat(sequence, count)
  vim.fn["repeat#set"](vim.keycode(sequence), count)
end

function _G.repeat_code_action(name, repeat_sequence)
  local bufnr = vim.api.nvim_get_current_buf()
  local count = vim.v.count
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
    buf = bufnr,
    once = true,
    callback = function()
      set_repeat(repeat_sequence, count)
    end,
  })
  vim.lsp.buf.code_action({filter = _G.filter_code_action(name), apply = true})
end

function _G.clojure_omnifunc_lsp_fallback(...)
  if vim.fn.exists("*fireplace#op_available") == 1
     and vim.fn["fireplace#op_available"]("complete") == 1 then
    return vim.fn["fireplace#omnicomplete"](...)
  end
  return vim.lsp.omnifunc(...)
end

local cmp_loaded
local cmp_nvim_lsp

local function is_cmd_installed(lsp)
  cmp_loaded, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  local cmd = vim.lsp.config[lsp].cmd
  return vim.fn.executable(cmd[1]) == 1
end

init.after_source('*/plugin/lspconfig.lua', function()

  vim.lsp.config('emmylua_ls', {
    on_init = function(client)
      -- If the workspace has its own emmylua_ls/lua_ls config file, defer to it.
      if client.workspace_folders then
        local path = client.workspace_folders[1].name
        if
          path ~= vim.fn.stdpath('config')
          and (vim.uv.fs_stat(path .. '/.emmyrc.json') or vim.uv.fs_stat(path .. '/.luarc.json'))
          then
            client.config.settings = {}
          end
        end
      end,
      settings = {
        emmylua = {
          -- Tell the server which Lua you're using (usually LuaJIT, for Neovim).
          runtime = { version = 'LuaJIT' },
          diagnostics = { globals = { 'vim' } },
          -- Make the server aware of Neovim runtime files.
          workspace = {
            library = {
              vim.env.VIMRUNTIME,
              -- For LSP Settings Type Annotations: https://github.com/neovim/nvim-lspconfig#lsp-settings-type-annotations
              vim.api.nvim_get_runtime_file('lua/lspconfig', false)[1],
            },
            -- Or pull in all of 'runtimepath'. May be slower! https://github.com/neovim/nvim-lspconfig/issues/3189
            -- library = vim.api.nvim_get_runtime_file('', true),
          },
        },
      },
    })
    vim.lsp.enable("emmylua_ls")
    vim.lsp.enable('vimdoc_ls')
    vim.lsp.enable('vimls')

  if is_cmd_installed("clojure_lsp") then

    vim.api.nvim_create_autocmd('LspAttach', {
      callback = function(ev)
        if vim.bo[ev.buf].filetype ~= 'clojure' then return end
        vim.bo[ev.buf].omnifunc = 'v:lua._G.clojure_omnifunc_lsp_fallback'
      end,
    })

    local function start_clojure_lsp(opts)
      local config = vim.deepcopy(vim.lsp.config['clojure_lsp'])
      local final_opts = vim.tbl_extend('force', {_root_markers = config.root_markers}, opts or {})
      if type(config.root_dir) == 'function' then
        config.root_dir(opts and opts.bufnr or 0, function(root_dir)
          config.root_dir = root_dir
          vim.schedule(function()
            vim.lsp.start(config, final_opts)
          end)
        end)
      else
        vim.lsp.start(config, final_opts)
      end
    end

    vim.api.nvim_create_autocmd('FileType', {
      pattern = {'clojure'}, -- in my setup only clojure_lsp is known to have this problem
      group = vim.api.nvim_create_augroup('clojure_lsp.enable', {}),
      callback = function(ev)
        -- https://github.com/neovim/neovim/issues/33061
        -- https://github.com/neovim/neovim/issues/33225
        -- Form taken from lsp.lua/lsp_enable_callback
        -- _root_markers is undocumented, but is how vim.lsp.enable() passes it in
        if not ev.file:match('^fugitive://') then
          start_clojure_lsp({bufnr = ev.buf})
        end
      end,
    })

    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function(ev)
        for _, file in ipairs(vim.lsp.config['clojure_lsp'].root_markers) do
          if vim.fn.filereadable(file) == 1 then
            return vim.schedule(function()
              -- attach=false: prestart only; FileType autocmd attaches clojure bufs
              start_clojure_lsp({attach = false})
            end)
          end
        end
      end
    })

    -- Trigger for existing buffers
    vim.cmd.doautoall('clojure_lsp.enable FileType')

    vim.lsp.config('clojure_lsp', {
      capabilities = cmp_loaded and cmp_nvim_lsp.default_capabilities()
        or vim.lsp.protocol.make_client_capabilities(),
      settings = {
        diagnostics = true,
      },
      on_attach = function(client, bufnr)
        local opts = { noremap = true, silent = true }

        vim.api.nvim_buf_set_keymap(
          bufnr, "v",
          "<localleader>ef",
          '<cmd>lua vim.lsp.buf.code_action({filter = _G.filter_code_action("extract-function"), apply = true})<CR>',
          opts
        )
        vim.api.nvim_buf_set_keymap(
          bufnr, "v",
          "<localleader>tf",
          '<cmd>lua vim.lsp.buf.code_action({filter = _G.filter_code_action("thread-first-all"), apply = true})<CR>',
          opts
        )

        vim.api.nvim_buf_set_keymap(
          bufnr, "v",
          "<localleader>uw",
          '<cmd>lua vim.lsp.buf.code_action({filter = _G.filter_code_action("unwind-thread"), apply = true})<CR>',
          opts
        )
        vim.api.nvim_buf_set_keymap(
          bufnr, "v",
          "<localleader>ua",
          '<cmd>lua vim.lsp.buf.code_action({filter = _G.filter_code_action("unwind-all"), apply = true})<CR>',
          opts
        )

        vim.api.nvim_buf_set_keymap(
          bufnr, "n",
          "<localleader>nsc",
          '<cmd>lua vim.lsp.buf.code_action({filter = _G.filter_code_action("clean-ns"), apply = true})<CR>',
          opts
        )
        vim.api.nvim_buf_set_keymap(
          bufnr, "n",
          "<Plug>(lsp-cycle-privacy)",
          '<cmd>lua _G.repeat_code_action("cycle-privacy", "<lt>Plug>(lsp-cycle-privacy)")<CR>',
          opts
        )
        vim.api.nvim_buf_set_keymap(
          bufnr, "n",
          "<localleader>lcp",
          "<Plug>(lsp-cycle-privacy)",
          opts
        )
      end,
    })
  end
end)

init.packadd("https://github.com/neovim/nvim-lspconfig.git")
