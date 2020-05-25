--
--------------------------------------------------------------------------------
--         File:  hover.lua
--------------------------------------------------------------------------------
--
-- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/util.lua
--

local api = vim.api
local vim = vim
local feature = 'textDocument/hover'
local default_callback_handler = vim.lsp.callbacks[feature]

local callback_handler = function(_, method, result)
  if popup_visible ~= 1 then return default_handle_callback(_, method, result) end
  -- TODO
end

local hover = function()
  if popup_visible ~= 1 then return end

  set_callback_handler()
  local items = api.nvim_call_function('complete_info', {{ 'eval', 'selected', 'items', 'user_data' }})
end

local insert_enter_handler = function()
  local timer = vim.loop.new_timer()

  timer:start(100, 80, vim.schedule_wrap(function()
    local changedtick = api.nvim_buf_get_changedtick(0)
    if changedtick ~= 
    hover()
  end))
end

local popup_visible = function()
  vim.fn.pumvisible()
end

local set_callback_handler = function()
  for _, client in pairs(vim.lsp.buf_get_clients(0)) do
    local default_callback = client.config.callbacks[feature] or vim.lsp.callbacks[feature]

    if default_callback ~= callback_function then
      client.config.callbacks[feature] = callback_handler
    end
  end
end

return {
  insert_enter_handler = insert_enter_handler
}
