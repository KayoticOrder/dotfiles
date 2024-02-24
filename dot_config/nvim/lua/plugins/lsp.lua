return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      keys[#keys + 1] = {
        "<leader>cr",
        function()
          vim.lsp.buf.rename()
          vim.cmd("silent! wa")
        end,
        desc = "Rename",
      }
    end,
  },
}
