return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", 
    "MunifTanjim/nui.nvim"
  },
  opts = {   
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = true,
      }
    },
    event_handlers = {
      {
        event = "file_open_requested",
        handler = function()
          require("neo-tree.command").execute({ action = "close" })
        end
      }
    }
  },
  keys = function()
    local find_buffer_by_type = function(type)
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local ft = vim.api.nvim_buf_get_option(buf, "filetype")
        if ft == type then return buf end
      end
      return 0
    end
    local toggle_neotree = function(toggle_command)
      if find_buffer_by_type "neo-tree" > 1 then
        require("neo-tree.command").execute { action = "close" }
      else
        toggle_command()
      end
    end

    return {
      {
        "<leader>fb",
        function()
          toggle_neotree(function() 
            require("neo-tree.command").execute { 
              action = "focus", 
              reveal = true, 
              position = "right"
            } 
          end)
        end,
        desc = "File Browser",
      },
    }
  end
}
