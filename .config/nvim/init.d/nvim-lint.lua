local init = require('init')

local function configure_lint()
  local lint = require("lint")

  local prose = { "alex", "blocklint", "codespell", "cspell", "languagetool", "proselint", "typos", "vale", "woke", "write_good" }

  local linters_by_ft = {
    ansible = { "ansible_lint" },
    awk = { "gawk" },
    bash = { "bash", "checkbashisms", "shellcheck" },
    bazel = { "buildifier" },
    beancount = { "bean_check" },
    c = { "checkpatch", "clangtidy", "cppcheck", "cpplint", "flawfinder" },
    cabal = { "hlint" },
    cf = { "cfn_lint", "cfn_nag" },
    clojure = { "clj-kondo", "joker" },
    cmake = { "cmakelint", "cmake_lint" },
    conf = { "compiler", "editorconfig-checker", "ls_lint", "lslint" },
    cpp = { "checkpatch", "clangtidy", "clazy", "cppcheck", "cpplint", "flawfinder" },
    crystal = { "ameba" },
    cs = { "fsharplint" },
    css = { "biomejs", "stylelint" },
    cue = { "cue" },
    dart = { "dclint" },
    dockerfile = { "hadolint" },
    dotenv = { "dotenv_linter" },
    ebnf = { "eugene" },
    eelixir = { "curlylint", "djlint", "htmlhint", "markuplint", "tidy" },
    ejs = { "curlylint", "djlint", "htmlhint", "markuplint", "tidy" },
    elixir = { "credo", "dialyxir" },
    erb = { "erb_lint", "herb" },
    eruby = { "erb_lint", "herb" },
    fennel = { "fennel" },
    fish = { "fish" },
    fortran = { "fortitude" },
    gdscript = { "gdlint" },
    gitcommit = vim.list_extend({ "commitlint", "gitlint" }, prose),
    glsl = { "glslc" },
    go = { "fieldalignment", "golangcilint", "revive", "staticcheck" },
    graphql = { "spectral" },
    groovy = { "npm-groovy-lint" },
    haml = { "curlylint", "djlint" },
    haskell = { "hlint" },
    hcl = { "snyk_iac", "tflint", "tfsec", "trivy" },
    heex = { "curlylint", "djlint", "htmlhint", "markuplint", "tidy" },
    hledger = { "hledger" },
    html = { "alex", "blocklint", "curlylint", "djlint", "htmlhint", "markuplint", "tidy" },
    htmldjango = { "curlylint", "djlint", "htmlhint", "markuplint", "tidy" },
    hlsl = { "dxc" },
    inko = { "inko" },
    janet = { "janet" },
    java = { "checkstyle", "pmd" },
    javascript = { "biomejs", "deno", "eslint", "eslint_d", "jshint", "oxlint", "quick-lint-js", "standardjs", "ts-standard" },
    javascriptreact = { "biomejs", "deno", "eslint", "eslint_d", "jshint", "oxlint", "quick-lint-js", "standardjs", "ts-standard" },
    jq = { "jq" },
    json = { "biomejs", "json_tool", "json5", "jsonlint", "tombi", "yq" },
    json5 = { "json5" },
    jsonc = { "biomejs" },
    kotlin = { "ktlint" },
    ksh = { "ksh", "shellcheck" },
    ledger = { "hledger" },
    lua = { "luac", "luacheck", "selene" },
    luau = { "selene" },
    make = { "checkmake", "mbake" },
    markdown = vim.list_extend({ "mado", "markdownlint", "markdownlint-cli2", "rumdl" }, prose),
    matlab = { "mh_lint", "mlint" },
    nix = { "deadnix", "nix", "statix" },
    oe = { "oelint-adv" },
    openapi = { "lint-openapi", "redocly", "spectral", "vacuum" },
    perl = { "perlcritic", "perlimports" },
    php = { "mago_analyze", "mago_lint", "php", "phpcs", "phpinsights", "phpmd", "phpstan", "psalm", "tlint" },
    pony = { "pony" },
    prisma = { "prisma-lint" },
    proto = { "buf_lint", "protolint" },
    puppet = { "puppet-lint" },
    python = { "bandit", "dmypy", "flake8", "fortitude", "mypy", "pflake8", "pycodestyle", "pydocstyle", "pylint", "pyrefly", "ruff", "vulture" },
    rego = { "opa_check", "regal" },
    robot = { "rflint" },
    rst = { "rstcheck", "rstlint", "sphinx-lint", "vale" },
    ruby = { "erb_lint", "robocop", "rubocop", "ruby", "standardrb" },
    rust = { "clippy" },
    salt = { "saltlint" },
    scss = { "stylelint" },
    sh = { "checkbashisms", "dash", "shellcheck" },
    slint = { "slang" },
    snakemake = { "snakemake" },
    solidity = { "solhint" },
    sql = { "sqruff", "squawk", "sqlfluff" },
    systemd = { "systemd-analyze", "systemdlint" },
    tcl = { "nagelfar", "tclint" },
    terraform = { "snyk_iac", "terraform_validate", "tflint", "tfsec", "tofu", "trivy" },
    tex = { "chktex", "lacheck" },
    spec = { "rpmlint", "rpmspec" },
    swift = { "swiftlint" },
    text = { "alex", "codespell", "cspell", "detect-secrets", "gitleaks", "languagetool", "ls_lint", "lslint", "panache", "proselint", "typos", "vale", "woke", "write_good", "zlint" },
    tf = { "snyk_iac", "terraform_validate", "tflint", "tfsec", "tofu", "trivy" },
    toml = { "tombi" },
    twig = { "twig-cs-fixer", "twigcs" },
    typescript = { "biomejs", "deno", "eslint", "eslint_d", "oxlint", "quick-lint-js", "standardjs", "ts-standard" },
    typescriptreact = { "biomejs", "deno", "eslint", "eslint_d", "oxlint", "quick-lint-js", "standardjs", "ts-standard" },
    vala = { "vala_lint" },
    verilog = { "slang", "svlint", "verilator" },
    vhdl = { "ghdl", "vsg" },
    vim = { "vint" },
    vue = { "eslint", "eslint_d", "stylelint" },
    yaml = { "actionlint", "ansible_lint", "saltlint", "spectral", "snyk_iac", "trivy", "yamllint", "yq", "zizmor" },
    zig = { "zig" },
    zsh = { "zsh" },
  }

  lint.linters_by_ft = vim.tbl_extend("force", lint.linters_by_ft, linters_by_ft)

  lint.linters.xlint = {
    cmd = "xlint",
    stdin = false,
    stream = "stdout",
    args = {},
    parser = require("lint.parser").from_errorformat("%f:%l: %m"),
  }

  lint.linters_by_ft.voidtemplate = { "xlint" }

  vim.api.nvim_create_autocmd({
    "BufWritePost",
    "BufReadPost",
    "InsertLeave",
    "TextChanged",
  }, {
    callback = function()
        lint.try_lint(nil, {
          filter = function(linter)
            if linter.name == "clj-kondo" then
              return #vim.lsp.get_clients({bufnr = 0, name = "clojure_lsp"}) == 0
            end
            return true
          end,
          ignore_errors = true -- if binary is missing, don't ENOENT https://github.com/mfussenegger/nvim-lint/issues/711 - bit of a blunt tool
        })
    end,
  })
end

init.packadd('https://github.com/mfussenegger/nvim-lint.git')
configure_lint()
