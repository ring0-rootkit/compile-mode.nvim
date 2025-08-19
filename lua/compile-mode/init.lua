local M = {}

local last_args = ""
local next = next

local vertical_split = true
local save_args = true

local last_pid = -1
local last_job_id = -1

local kill_msg = "Press ME to stop the program" 

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

local function kill()
	os.execute(string.format("kill %d", last_pid))
	last_pid = -1
	last_job_id = -1
	if buf ~= nil then
		local end_date = vim.fn.strftime("%c")
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "Compilation stopped at " .. end_date })
	end
end

M.compile = function()
	if last_pid ~= -1 then
		kill()
	end
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
	end

	local start_date = vim.fn.strftime("%c")
	local append_data = function(id, data, event)
		if id ~= last_job_id then
			return
		end

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
			last_pid = -1
			last_job_id = -1
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-*- compile-mode; directory: '" .. vim.fn.getcwd() .. "' -*-" })
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "Compilation started at " .. start_date })
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "Command: " .. last_args })
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { kill_msg })

	local job_id = vim.fn.jobstart(last_args, {
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = append_data,
		on_stderr = append_data,
		on_exit = append_data,
	})

	local pid = vim.fn.jobpid(job_id)
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "PID: " .. pid })
	last_pid = pid
	last_job_id = job_id

	vim.api.nvim_win_set_buf(win, buf)
end

M.open_file = function()
	local line = vim.api.nvim_get_current_line()

	if line == kill_msg then
		kill()
		return
	end

	local file, line_num, char_num = string.match(line, "(%S+):(%d+):(%d+)")
	if not file then return end
	if io.open(vim.fn.fnameescape(file), "r") == nil then return end

  -- Find the non-compilation window
	local target_win
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(win)
			local buf_name = vim.api.nvim_buf_get_name(buf)
			if not string.match(buf_name, "*compilation*") then
			  target_win = win
			  break
		end
	end

  -- If no suitable window found, create one
	if not target_win then
		vim.cmd("vsplit")
		target_win = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_set_current_win(target_win)
	vim.cmd("edit " .. vim.fn.fnameescape(file))

	if line_num and char_num then
		vim.api.nvim_win_set_cursor(target_win, {tonumber(line_num), tonumber(char_num) - 1})
	end
end

M.compile_setup = function(opts)
	-- sets the arguments to be executed.
	if opts == nil or next(opts.fargs) == nil then
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
			vim.keymap.set('n', '<CR>', M.open_file)
			vim.cmd([[
				syntax match CompHeader /^-\*- compile-mode;.* -\*-/
				syntax match CompParam /^Compilation started at .*/
				syntax match CompParam /^Compilation finished at .*/
				syntax match CompParam /^Command:/
				syntax match CompParam /^PID:/

				syntax match CompError /^Press ME to stop the program$/
				syntax match CompError /^Compilation stopped at .*/
				syntax match CompError /^error\(.*?:\)\?/
				syntax match CompWarn /^warning\(.*?:\)\?/

				syntax match CompTip /^tip\(.*?:\)\?/
				syntax match CompHelp /^help\(.*?:\)\?/
				syntax match CompNote /^note\(.*?:\)\?/

				syntax match CompLink /\S*[^0-9 ]\+\S*:\d\+:\d\+/

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
