-- ENVI DEFAULT NEOVIM CONFIG
-- Cool visual settings

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.linebreak = true
vim.opt.showmode = false
vim.opt.cmdheight = 0
vim.opt.laststatus = 3
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.fillchars = "eob: ,fold: "

-- Cool colorscheme
pcall(vim.cmd.colorscheme, "habamax")

-- Cool statusline function
local function statusline()
  local mode_map = {
    ['n'] = 'NORMAL', ['i'] = 'INSERT', ['v'] = 'VISUAL', ['V'] = 'V-LINE',
    [''] = 'V-BLOCK', ['c'] = 'COMMAND', ['R'] = 'REPLACE', ['t'] = 'TERMINAL'
  }
  
  local mode = mode_map[vim.fn.mode()] or vim.fn.mode():upper()
  local filename = vim.fn.expand('%:t') ~= '' and vim.fn.expand('%:t') or '[No Name]'
  local modified = vim.bo.modified and ' [+]' or ''
  local readonly = vim.bo.readonly and ' [RO]' or ''
  local filetype = vim.bo.filetype ~= '' and ' ' .. vim.bo.filetype:upper() or ''
  local line_col = string.format(' %d:%d ', vim.fn.line('.'), vim.fn.col('.'))
  local percentage = string.format(' %d%% ', math.floor(100 * vim.fn.line('.') / vim.fn.line('$')))
  
  return string.format(
    '%%#StatusLineAccent# %s %%#StatusLine# %s%s%s %%=%%#StatusLine#%s%s%s',
    mode, filename, modified, readonly, filetype, percentage, line_col
  )
end

-- Create global function for statusline
_G.statusline_func = statusline

-- Set statusline
vim.opt.statusline = "%!v:lua.statusline_func()"

-- Define highlight groups
vim.api.nvim_set_hl(0, 'StatusLineAccent', { fg = '#000000', bg = '#00ff87', bold = true })
vim.api.nvim_set_hl(0, 'StatusLine', { fg = '#ffffff', bg = '#444444' })
