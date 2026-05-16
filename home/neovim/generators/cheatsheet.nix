{ pkgs, staticConfig }:

pkgs.runCommandLocal "nvim-cheatsheet.md"
  {
    nativeBuildInputs = [ pkgs.lua5_4 ];
  }
  ''
    lua <<'EOF' > "$out"
    package.path = "${staticConfig}/lua/?.lua;${staticConfig}/lua/?/init.lua;" .. package.path

    local registry = require("config.keymap_registry")

    local function enabled(entry)
      if entry.doc == false then
        return false
      end
      if entry.enabled == nil then
        return true
      end
      if type(entry.enabled) == "function" then
        return entry.enabled()
      end
      return entry.enabled
    end

    local function escape(text)
      return tostring(text):gsub("|", "\\|")
    end

    local function mode_text(mode)
      if type(mode) == "table" then
        return table.concat(mode, ", ")
      end
      return tostring(mode)
    end

    local section_order = {
      "Navigation",
      "Search",
      "Editing",
      "Git",
      "LSP",
      "Diagnostics",
      "Testing",
      "Debug",
      "Sessions",
      "Trouble",
      "UI",
      "LaTeX",
    }

    local buckets = {}
    for _, section in ipairs(section_order) do
      buckets[section] = {}
    end

    for _, entry in ipairs(registry) do
      if enabled(entry) then
        local section = entry.section or "Other"
        buckets[section] = buckets[section] or {}
        table.insert(buckets[section], entry)
      end
    end

    io.write("# Neovim Cheat Sheet\n\n")
    io.write("Generated from `lua/config/keymap_registry.lua`.\n")

    for _, section in ipairs(section_order) do
      local entries = buckets[section]
      if entries and #entries > 0 then
        table.sort(entries, function(a, b)
          if a.lhs == b.lhs then
            return (a.context or "") < (b.context or "")
          end
          return a.lhs < b.lhs
        end)

        io.write("\n## " .. section .. "\n\n")
        io.write("| Key | Mode | Description | Context |\n")
        io.write("| --- | --- | --- | --- |\n")
        for _, entry in ipairs(entries) do
          io.write(
            string.format(
              "| `%s` | `%s` | %s | %s |\n",
              escape(entry.lhs),
              escape(mode_text(entry.mode)),
              escape(entry.desc or ""),
              escape(entry.context or "")
            )
          )
        end
      end
    end
    EOF
  ''
