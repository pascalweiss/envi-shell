-- ENVI DEFAULT NEOVIM CONFIG
-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

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

-- Setup plugins with lazy.nvim
require("lazy").setup({
  -- Git signs for showing git changes in the gutter
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        signs = {
          add          = { text = '+' },
          change       = { text = '~' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '~' },
          untracked    = { text = '┆' },
        },
        signcolumn = true,
        numhl = false,
        linehl = false,
        word_diff = false,
        current_line_blame = false,
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = 'eol',
          delay = 1000,
        },
        preview_config = {
          border = 'single',
          style = 'minimal',
          relative = 'cursor',
          row = 0,
          col = 1
        },
      })
    end,
  },
}, {
  -- Lazy.nvim configuration
  ui = {
    border = "rounded",
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})


-- Basic file change detection (no auto-refresh)
vim.api.nvim_create_autocmd({'FocusGained', 'BufEnter'}, {
  pattern = '*',
  command = 'if mode() != "c" | checktime | endif',
})

-- Key mapping for manual gitsigns refresh and diff view
vim.keymap.set('n', '<leader>gr', '<cmd>Gitsigns refresh<CR><cmd>e<CR>', { desc = "Refresh gitsigns" })
vim.keymap.set('n', '<leader>gd', '<cmd>Gitsigns diffthis<CR>', { desc = "Open git diff view" })
vim.keymap.set('n', '<leader>gq', '<cmd>diffoff<CR><cmd>only<CR>', { desc = "Exit git diff view" })

-- Hunk search mode - like search mode but for git hunks
local hunk_search_mode = false

vim.keymap.set('n', '<leader>gh', function()
  hunk_search_mode = true
  require('gitsigns').next_hunk()
  print("Hunk search mode ON - use n/N to navigate hunks, press <Esc> to exit")
end, { desc = "Start hunk search mode" })

-- Override n and N when in hunk search mode
vim.keymap.set('n', 'n', function()
  if hunk_search_mode then
    require('gitsigns').next_hunk()
  else
    vim.cmd('normal! n')
  end
end)

vim.keymap.set('n', 'N', function()
  if hunk_search_mode then
    require('gitsigns').prev_hunk()
  else
    vim.cmd('normal! N')
  end
end)

-- Exit hunk search mode with Escape
vim.keymap.set('n', '<Esc>', function()
  if hunk_search_mode then
    hunk_search_mode = false
    print("Hunk search mode OFF")
  else
    -- Normal escape behavior
    vim.cmd('nohlsearch')
  end
end)
