--
--------------------------------------------------------------------------------
--         File:  hover.lua
--------------------------------------------------------------------------------
--
-- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/util.lua
--

local api = vim.api
local default_callback_handler = vim.lsp.callbacks[feature]
local feature = 'textDocument/hover'
local hover = {}
local util = require 'util'
local vim = vim

-- TODO Move to method
local hover_defaults = {
  buffer_changes = 0,
  insert_mode = false,
  selected_popup_item = nil,
  selected_popup_item_index = -1,
  winnr = nil
}

local popup_visible = function()
  return vim.fn.pumvisible() ~= 0
end

local callback_handler = function(_, method, result)
  if popup_visible() == false then return default_callback_handler(_, method, result, _) end
  if not (result and result.contents) then return end

  util.focusable_float(method, function()
    local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    markdown_lines = vim.lsp.util.trim_empty_lines(markdown_lines)

    if vim.tbl_isempty(markdown_lines) then return end

    local bufnr, winnr
    local position = vim.fn.pum_getpos()
    local total_column = api.nvim_get_option('columns')
    local align

    if position['col'] < total_column/2 then
      align = 'right'
    else
      align = 'left'
    end

    bufnr, winnr = util.fancy_floating_markdown(markdown_lines, {
        pad_left = 1; pad_right = 1;
        col = position['col']; width = position['width']; row = position['row']-1;
        align = align
      })
    hover.winnr = winnr

    if winnr ~= nil and api.nvim_win_is_valid(winnr) then
      vim.lsp.util.close_preview_autocmd({"CursorMoved", "BufHidden", "InsertCharPre"}, winnr)
    end

    local hover_len = #vim.api.nvim_buf_get_lines(bufnr,0,-1,false)[1]
    local win_width = vim.api.nvim_win_get_width(0)

    if hover_len > win_width then
      vim.api.nvim_win_set_width(winnr,math.min(hover_len,win_width))
      vim.api.nvim_win_set_height(winnr,math.ceil(hover_len/win_width))
      vim.wo[winnr].wrap = true
    end

    return bufnr, winnr
  end)
end

local set_callback_handler = function()
  for _, client in pairs(vim.lsp.buf_get_clients(0)) do
    local default_callback = client.config.callbacks[feature] or vim.lsp.callbacks[feature]

    if default_callback ~= callback_function then
      client.config.callbacks[feature] = callback_handler
    end
  end
end

local decode_user_data = function(user_data)
  if user_data == nil or (user_data ~= nil and #user_data == 0) then return end

  return  vim.fn.json_decode(user_data)
end

local lsp_hover = function()
  for _, value in pairs(vim.lsp.buf_get_clients(0)) do
    if value.resolved_capabilities.hover == false then return false end
  end

  return true
end

local update_buffer_changes = function()
  buffer_changes = api.nvim_buf_get_changedtick(0)
  if hover.buffer_changes == buffer_changes then return false end

  hover.buffer_changes = buffer_changes

  return hover_buffer_changes
end

local update_selected_popup_item = function()
  local complete_info = api.nvim_call_function('complete_info', {{ 'eval', 'selected', 'items', 'user_data' }})
  if complete_info['selected'] == -1 or complete_info['selected'] == hover.selected_popup_item_index then return false end

  hover.selected_popup_item_index = complete_info['selected']

  return complete_info['items'][complete_info['selected'] + 1]
end

local hover_popup = function()
  local selected_popup_item = update_selected_popup_item()
  if popup_visible() == false or update_buffer_changes() == false or selected_popup_item == false then return end

  -- TODO
      if hover.winnr ~= nil and api.nvim_win_is_valid(hover.winnr) then
        api.nvim_win_close(hover.winnr, true)
      end

  local decoded_user_data = decode_user_data(selected_popup_item['user_data'])
  if decoded_user_data == nil then return end

  -- require 'pl.pretty'.dump(decoded_user_data)
  if lsp_hover() == false then return end

  local row, col = unpack(api.nvim_win_get_cursor(0))
  row = row - 1
  local line = api.nvim_buf_get_lines(0, row, row+1, true)[1]
  col = vim.str_utfindex(line, col)

  local params = {
    textDocument = vim.lsp.util.make_text_document_params();
    position = { line = row; character = col-1; }
  }

  set_callback_handler()

  vim.lsp.buf_request(api.nvim_get_current_buf(), 'textDocument/hover', params)
end

local insert_enter_handler = function()
  hover.insert_mode = true
  -- set_callback_handler()
  local timer = vim.loop.new_timer()

  timer:start(100, 80, vim.schedule_wrap(function()
    hover_popup()

    if hover.insert_leave == false and timer:is_closing() == false then
      timer:stop()
      timer:close()
    end
  end))
end

local insert_leave_handler = function()
  hover = hover_defaults
end

return {
  insert_enter_handler = insert_enter_handler,
  insert_leave_handler = insert_leave_handler
}
