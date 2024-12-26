return {
  "nvim-treesitter/nvim-treesitter", 
  build= ":TSUpdate",      
  config = function()
    -- filetype detection
    vim.filetype.add({
      pattern = { [".*/hypr/.*%.conf"] = "hyprlang" },
    })
    -- setup
    local config = require("nvim-treesitter.configs")
    config.setup({
      ensure_installed = {"lua", "javascript", "cpp", "make", "hyprlang", "php", "json"},
      highlight = { enable = true },
      indent = { enable = true }})
  end
}
