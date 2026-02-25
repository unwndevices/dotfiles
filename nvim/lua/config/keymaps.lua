-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>+x", function()
  local file = vim.fn.expand("%:p")
  local current_perm = vim.fn.getfperm(file)
  -- Add execute permission to user, group, and others
  local new_perm = current_perm:gsub("(.)(.)(.)(.)(.)(.)(.)(.)(.)$", function(u1, u2, u3, g1, g2, g3, o1, o2, o3)
    return u1 .. u2 .. "x" .. g1 .. g2 .. "x" .. o1 .. o2 .. "x"
  end)
  vim.fn.setfperm(file, new_perm)
  vim.notify("Changed permissions: " .. current_perm .. " → " .. new_perm)
end, { noremap = true, silent = true })

vim.keymap.set("n", "<leader>+w", function()
  local file = vim.fn.expand("%:p")
  local current_perm = vim.fn.getfperm(file)
  -- Add write permission to user, group, and others
  local new_perm = current_perm:gsub("(.)(.)(.)(.)(.)(.)(.)(.)(.)$", function(u1, u2, u3, g1, g2, g3, o1, o2, o3)
    return u1 .. "w" .. u3 .. g1 .. g2 .. g3 .. o1 .. o2 .. o3
  end)
  vim.fn.setfperm(file, new_perm)
  vim.notify("Changed permissions: " .. current_perm .. " → " .. new_perm)
end, { noremap = true, silent = true })
