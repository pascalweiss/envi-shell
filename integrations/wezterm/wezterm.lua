-- ENVI WEZTERM CONFIGURATION
-- Symlinked to ~/.config/wezterm/wezterm.lua by integrations/wezterm/init.sh.
-- WezTerm reloads this file automatically on save.
--
-- Tabs are filled with a color of their own, like iTerm2's tab colors.
-- A tab's color comes from, in this order:
--   1. the picker:      Cmd+Alt+C
--   2. the shell:       tabcolor red [title]   (user vars tab_color and tab_title, see init.sh)
--   3. nothing:         neutral gray
-- Cmd+Shift+R renames a tab.

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Named colors for the picker and for `tabcolor <name>`; a #rrggbb value works too
local palette = {
  red    = '#c0392b',
  orange = '#d35400',
  yellow = '#b7950b',
  green  = '#27ae60',
  teal   = '#16a085',
  blue   = '#2e86c1',
  purple = '#8e44ad',
  pink   = '#c2185b',
  gray   = '#4a4a4a',
}
local palette_order = { 'red', 'orange', 'yellow', 'green', 'teal', 'blue', 'purple', 'pink', 'gray' }
local neutral = '#3a3a3a'

-- Picker choices survive config reloads in wezterm.GLOBAL, keyed by tab id
wezterm.GLOBAL.tab_colors = wezterm.GLOBAL.tab_colors or {}

local function resolve(name)
  if not name or name == '' or name == 'off' then return nil end
  return palette[name] or (name:match('^#%x%x%x%x%x%x$') and name) or nil
end

local function tab_color(tab)
  local picked = wezterm.GLOBAL.tab_colors[tostring(tab.tab_id)]
  if picked then return picked end
  local var = tab.active_pane.user_vars.tab_color
  return resolve(var) or neutral
end

-- Window and font
-- Fira Code is soft and round at small sizes; the Nerd Font variant adds icons.
-- Light hinting plus horizontal LCD antialiasing keeps glyphs smooth, which
-- matters most on the non-Retina external display.
config.font = wezterm.font_with_fallback { 'FiraCode Nerd Font Mono', 'Fira Code', 'Menlo' }
config.font_size = 12.5

-- SF Mono ships inside Terminal.app without being installed system-wide
config.font_dirs = { '/System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts' }

-- Cmd+Alt+F cycles through these live (window only, the config stays as is);
-- the current choice is shown at the right of the tab bar.
local font_trials = {
  { name = 'JetBrainsMono Nerd Font Mono', size = 12.5 },
  { name = 'SF Mono', size = 12.5 },
  { name = 'Menlo', size = 12.5 },
  { name = 'Monaco', size = 12.0 },
  { name = 'FiraCode Nerd Font Mono', size = 12.5 },
  { name = 'JuliaMono', size = 12.5 },
  { name = 'UbuntuMono Nerd Font Mono', size = 14.5 },
  { name = 'Agave Nerd Font Mono', size = 14.0 },
  { name = 'PT Mono', size = 12.5 },
}
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' } -- no ligatures, like iTerm2
config.freetype_load_target = 'Light'
config.freetype_render_target = 'HorizontalLcd'
config.front_end = 'WebGpu'
-- Tomorrow Night ships bright black (color 8) as #000000, which is invisible on
-- its background; zsh-autosuggestions and other dimmed output use exactly that
-- color, so it becomes a readable gray here.
local scheme = wezterm.color.get_builtin_schemes()['Tomorrow Night']
scheme.brights[1] = '#7c7f7e'
config.color_schemes = { ['Tomorrow Night (envi)'] = scheme }
config.color_scheme = 'Tomorrow Night (envi)'
config.window_padding = { left = 4, right = 4, top = 2, bottom = 2 }
config.initial_cols = 200
config.initial_rows = 50

-- macOS: both Option keys act as the system modifier so DE-layout characters
-- and dead keys work with either Option key: @ (Opt+L), | (Opt+7), \ (Opt+Shift+7),
-- {} (Opt+8/9), [] (Opt+5/6), ~ (Opt+N). WezTerm defaults send_composed_key_when_left_alt_is_pressed
-- to false (sending Esc+key instead of the composed character).
config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true

-- Tab bar: pill-shaped tabs in the title bar, next to the macOS window buttons.
-- The fancy bar takes its height from window_frame.font_size; the pills are
-- drawn by format-tab-title with the rounded Nerd Font caps, so the tab's own
-- background is set to the bar color and only the pill shows.
local bar_bg = '#16181a'
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.use_fancy_tab_bar = true
config.window_frame = {
  font = wezterm.font { family = 'FiraCode Nerd Font Mono', weight = 'Bold' },
  font_size = 14.0,
  active_titlebar_bg = bar_bg,
  inactive_titlebar_bg = bar_bg,
}
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
-- Tabs size to their title, between these widths (in cells, caps and gap
-- included); WezTerm shrinks them below the minimum only when space runs out
local tab_min_width = 20
config.tab_max_width = 42
config.show_new_tab_button_in_tab_bar = true
config.colors = {
  tab_bar = {
    background = bar_bg,
    inactive_tab_edge = bar_bg,
    active_tab = { bg_color = bar_bg, fg_color = '#ffffff' },
    inactive_tab = { bg_color = bar_bg, fg_color = '#8a8a8a' },
    inactive_tab_hover = { bg_color = bar_bg, fg_color = '#e0e0e0' },
    new_tab = { bg_color = bar_bg, fg_color = '#6a6a6a' },
    new_tab_hover = { bg_color = bar_bg, fg_color = '#ffffff' },
  },
}

local cap_left = utf8.char(0xe0b6)  -- Nerd Font left half circle
local cap_right = utf8.char(0xe0b4) -- Nerd Font right half circle

wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
  local base = wezterm.color.parse(tab_color(tab))
  local bg, fg
  -- Active: full color and white bold text; inactive: dark and muted.
  -- Nothing is added to the label, so a tab keeps its width either way.
  -- Note: `hover` is only used when `use_fancy_tab_bar` is false; with the fancy
  -- tab bar WezTerm computes `hover` from terminal-grid columns instead of the
  -- fancy tab bar's pixel positions (offset by the 70px macOS traffic lights,
  -- window_frame.font_size, and 1.0-cell per-tab padding), which highlights the
  -- wrong tab (upstream wezterm#5164).
  if tab.is_active then
    bg, fg = base:lighten(0.05), '#ffffff'
  elseif hover and not cfg.use_fancy_tab_bar then
    bg, fg = base:darken(0.3), '#e0e0e0'
  else
    bg, fg = base:desaturate(0.4):darken(0.6), '#8a8a8a'
  end
  -- Title: Cmd+Shift+R, then `tabcolor <color> <title>`, then the pane title
  local title = tab.tab_title
  if not title or title == '' then title = tab.active_pane.user_vars.tab_title end
  if not title or title == '' then title = tab.active_pane.title end
  -- Center the label inside the pill; 3 cells of the width go to the two caps
  -- and the gap after the tab
  local label = (tab.tab_index + 1) .. '  ' .. title
  local width = math.min(math.max(wezterm.column_width(label) + 6, tab_min_width), max_width) - 3
  label = wezterm.truncate_right(label, width - 2)
  local free = width - wezterm.column_width(label)
  local left = math.floor(free / 2)
  local body = string.rep(' ', left) .. label .. string.rep(' ', free - left)
  return {
    { Background = { Color = bar_bg } },
    { Foreground = { Color = bg } },
    { Text = cap_left },
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Attribute = { Intensity = tab.is_active and 'Bold' or 'Normal' } },
    { Text = body },
    { Background = { Color = bar_bg } },
    { Foreground = { Color = bg } },
    { Text = cap_right .. ' ' },
  }
end)

-- Color picker for the current tab
local choices = {}
for _, name in ipairs(palette_order) do
  table.insert(choices, {
    id = name,
    label = wezterm.format {
      { Background = { Color = palette[name] } }, { Foreground = { Color = '#ffffff' } },
      { Text = '   ' .. name .. '   ' },
    },
  })
end
table.insert(choices, { id = 'off', label = 'no color' })

-- Key bindings. Every binding goes through bind(), which also records it for
-- the cheat sheet (Cmd+Alt+K) and for `wezterm-help`, so the help can never
-- drift from what is actually bound.
config.keys = {}
local cheat_sheet = {}
local cheat_key, cheat_mods, cheat_label = 'k', 'CMD|ALT', 'Cmd+Alt+K'

local function bind(key, mods, label, desc, action)
  table.insert(config.keys, { key = key, mods = mods, action = action })
  table.insert(cheat_sheet, { label = label, desc = desc, action = action })
end

bind('h', 'CMD|ALT', 'Cmd+Alt+H', 'previous tab', act.ActivateTabRelative(-1))
bind('l', 'CMD|ALT', 'Cmd+Alt+L', 'next tab', act.ActivateTabRelative(1))

bind('c', 'CMD|ALT', 'Cmd+Alt+C', 'pick a tab color', act.InputSelector {
  title = 'Tab color',
  choices = choices,
  action = wezterm.action_callback(function(window, pane, id)
    if not id then return end
    local key = tostring(window:active_tab():tab_id())
    wezterm.GLOBAL.tab_colors[key] = (id ~= 'off') and palette[id] or nil
    window:set_right_status('') -- forces the tab bar to redraw
  end),
})

bind('r', 'CMD|SHIFT', 'Cmd+Shift+R', 'rename tab (empty: remove the name)', act.PromptInputLine {
  description = 'Tab title',
  action = wezterm.action_callback(function(window, pane, line)
    if line then window:active_tab():set_title(line) end
  end),
})

bind('f', 'CMD|ALT', 'Cmd+Alt+F', 'cycle through fonts (this window only)', wezterm.action_callback(function(window, pane)
  local i = ((wezterm.GLOBAL.font_trial or 0) % #font_trials) + 1
  wezterm.GLOBAL.font_trial = i
  local f = font_trials[i]
  local overrides = window:get_config_overrides() or {}
  overrides.font = wezterm.font_with_fallback { f.name, 'Menlo' }
  overrides.font_size = f.size
  window:set_config_overrides(overrides)
  window:set_right_status(wezterm.format {
    { Foreground = { Color = '#f0c674' } },
    { Text = string.format(' font %d/%d: %s %.1f ', i, #font_trials, f.name, f.size) },
  })
end))

-- Shell commands from init.sh, listed in the help next to the bindings
local shell_commands = {
  { label = 'tabcolor <1-9|name> [title]', desc = 'color the tab, optionally name it (no argument: list colors)' },
  { label = 'tabname [title]', desc = 'name the tab (no argument: remove the name)' },
  { label = 'wezterm-help', desc = 'print this overview' },
}

local function cheat_lines()
  local lines = { 'WEZTERM SHORTCUTS', '' }
  for _, e in ipairs(cheat_sheet) do
    table.insert(lines, string.format('  %-28s %s', e.label, e.desc))
  end
  table.insert(lines, string.format('  %-28s %s', cheat_label, 'show this cheat sheet'))
  table.insert(lines, '')
  table.insert(lines, 'SHELL COMMANDS')
  table.insert(lines, '')
  for _, e in ipairs(shell_commands) do
    table.insert(lines, string.format('  %-28s %s', e.label, e.desc))
  end
  return lines
end

-- Cheat sheet: choosing a binding runs it
local cheat_choices = {}
for i, e in ipairs(cheat_sheet) do
  table.insert(cheat_choices, { id = tostring(i), label = string.format('%-14s %s', e.label, e.desc) })
end
for _, e in ipairs(shell_commands) do
  table.insert(cheat_choices, { id = 'shell', label = string.format('%-14s %s', 'shell', e.label .. '  ' .. e.desc) })
end
bind(cheat_key, cheat_mods, cheat_label, 'show this cheat sheet', act.InputSelector {
  title = 'WezTerm shortcuts (Enter runs a binding)',
  choices = cheat_choices,
  action = wezterm.action_callback(function(window, pane, id)
    local e = id and cheat_sheet[tonumber(id)]
    if e then window:perform_action(e.action, pane) end
  end),
})
table.remove(cheat_sheet) -- the cheat sheet itself is added by cheat_lines()

-- The same overview as a file for the `wezterm-help` shell command
local help_file = io.open(wezterm.home_dir .. '/.cache/envi-wezterm-help.txt', 'w')
if help_file then
  help_file:write(table.concat(cheat_lines(), '\n') .. '\n')
  help_file:close()
end

return config
