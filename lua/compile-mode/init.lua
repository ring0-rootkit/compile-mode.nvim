local M = {}

local last_args = ""
local next = next

local vertical_split = true
local save_args = true

local function create_buffer()
	local buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_buf_set_name(buf, "*compilation*")
	return buf
end

local buf = nil

local function is_buffer_open(buffer_id)
	local windows = vim.api.nvim_tabpage_list_wins(0)

	for _, win_id in ipairs(windows) do
		if vim.api.nvim_win_get_buf(win_id) == buffer_id then
			return win_id
		end
	end

	return nil
end

local function savetolv()
	if lv then
		lv["compile_args"] = last_args
	end
end

M.compile = function()
	if last_args == "" then
		-- prompt user if no argument has been saved yet.
		print("compile-mode: compile command not set.")
		return
	end

	local win = is_buffer_open(buf)
	if win == nil then
		if vertical_split then
			vim.cmd("botright vnew")
		else
			vim.cmd("botright new")
		end
		win = vim.api.nvim_get_current_win()
	end

	if buf == nil then
		buf = create_buffer()
		-- TODO: remove command, maybe add command to go to file
		-- vim.api.nvim_buf_set_keymap(buf, "n", "q", ":quit<CR>", { noremap = true, silent = true })
	end

	local start_date = vim.fn.strftime("%c")
	local append_data = function(_, data, event)
		local end_date = vim.fn.strftime("%c")
		if event == "stdout" then
			if data then
				vim.api.nvim_buf_set_lines(buf, -1, -1, false, data)
			end
		end
		if event == "stderr" then
			if data then
				vim.api.nvim_buf_set_lines(buf, -1, -1, false, data)
			end
		end
		if event == "exit" then
			vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "Compilation finished at " .. end_date })
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-*- compile-mode; directory: '" .. vim.fn.getcwd() .. "' -*-" })
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "Compilation started at " .. start_date })
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "command: " .. last_args })
	vim.fn.jobstart(last_args, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = append_data,
		on_stderr = append_data,
		on_exit = append_data,
	})

	vim.api.nvim_win_set_buf(win, buf)
end

M.open_file = function()
  local line = vim.fn.line('.')
  local col = vim.fn.col('.')
  local line_text = vim.fn.getline(line)

  local regex = vim.regex([[\S*:\d:\d]])
  local match_start, match_end = regex:match_str(line_text)

  if match_start and (col >= match_start+1) and (col <= match_end+1) then
    local matched_text = string.sub(line_text, match_start+1, match_end)
	print(matched_text)
  end
end

M.compile_setup = function(opts)
	-- sets the arguments to be executed.
	if next(opts.fargs) == nil then
		last_args = vim.fn.input({
			prompt = "Compile command: ",
			default = last_args,
		})

		if last_args == "" then
			return
		end
	else
		last_args = opts.args
	end

	if save_args then
		savetolv()
	end
	M.compile()
end

M.setup = function(opts)
	if opts then
		if opts.save_args then
			save_args = opts.save_args
		end
		if opts.vertical_split then
			vertical_split = opts.vertical_split
		end
	end

	vim.api.nvim_create_user_command("Compile", M.compile_setup, { nargs = "*" })
	vim.api.nvim_create_user_command("Recompile", M.compile, {})
	vim.api.nvim_create_user_command("CompileSplitToggle", function()
		vertical_split = not vertical_split
	end, {})

	vim.api.nvim_create_autocmd('BufWinEnter', {
		pattern = '*compilation*',
		callback = function()
			vim.cmd([[
				syntax match CompHeader /-\*- compile-mode;.* -\*-/
				syntax match CompParam /Compilation started at .*/
				syntax match CompParam /Compilation finished at .*/
				syntax match CompParam /command:/

				syntax match CompError /^error\(.*?:\)\?/
				syntax match CompWarn /^warning\(.*?:\)\?/

				syntax match CompTip /^tip\(.*?:\)\?/
				syntax match CompHelp /^help\(.*?:\)\?/
				syntax match CompNote /^note\(.*?:\)\?/

				syntax match CompLink /\S*:\d:\d/

				highlight link CompHeader Title
				highlight link CompParam Identifier
				highlight link CompError ErrorMsg
				highlight link CompWarn WarningMsg

				highlight link CompTip MoreMsg
				highlight link CompHelp MoreMsg
				highlight link CompNote MoreMsg

				highlight link CompLink Directory
			]])
		end
	})
end

return M
