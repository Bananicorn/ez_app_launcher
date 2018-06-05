#!/usr/bin/env luajit
package.path = package.path..";../?.lua"

local ffi = require("ffi")
local bit = require("bit")
local bor = bit.bor

function init_globals ()
	X11 = require("x11.X11")()
	config = require("config")
	apps = get_applications()
	sel_app = math.floor(#apps / 2)
	height = 200
	width = height * 5
	h_unit = height / 100
	box_size = h_unit * 90
	padding = h_unit * 5
	amount = #apps
end


function scandir(directory)
	local i = 1
	local dir_contents = {}
	local popen = io.popen
	local path_file = popen('ls -a "' .. directory .. '"')
	for filename in path_file:lines() do
		dir_contents[i] = filename
		i = i + 1
	end
	path_file:close()
	return dir_contents
end

function check_file_ending(filename)
	for i = 1, #config.allowed_file_types do
		local suffix = config.allowed_file_types[i]
		if filename:find("%." .. suffix .. "$") then
			return true
		end
	end
	return false
end

function get_applications()
	local dir_contents = scandir(config.desktop_path)
	local apps = {}
	for i = 1, #dir_contents do
		local file = dir_contents[i]
		if check_file_ending(file) then
			local app = {
				name = file:gsub("%..*$", ""),
				executable = config.desktop_path .. "/" .. file
			}
			apps[#apps + 1] = app
		end
	end
	return apps
end

function prev_application()
	if sel_app - 1 > 0 then
		sel_app = sel_app - 1
	end
end

function next_application()
	if sel_app + 1 <= #apps then
		sel_app = sel_app + 1
	end
end

function start_application()
	if apps and sel_app > 0 and sel_app <= #apps then
		-- os.execute(apps[sel_app].executable)
		io.popen(apps[sel_app].executable)
	end
end

-- some global variables
local dis = nil;
local screen = nil;
local win = nil;
local gc = nil;

-- important work routines
local function init_x()

	dis = X11.XOpenDisplay(nil);
	screen = DefaultScreen(dis);
	local black = BlackPixel(dis,screen);
	local white = WhitePixel(dis, screen);

	win = X11.XCreateSimpleWindow(dis, DefaultRootWindow(dis), 0, 0, width, height, 5, black, white);

	local wm_class_hint = X11.XAllocClassHint()
	local class = "pop-up"
	local c_str_class = ffi.new("char[?]", #class)
	ffi.copy(c_str_class, class)
	
	local name = ""
	local c_str_name = ffi.new("char[?]", #name)
	ffi.copy(c_str_name, name)
	
	wm_class_hint.res_class = c_str_class
	wm_class_hint.res_name = c_str_name
	
	X11.XSetClassHint(dis, win, wm_class_hint)
	X11.XSetStandardProperties(dis, win, "simple_app_launcher", "", None, nil, 0, nil)
	X11.XSelectInput(dis, win, bor(ExposureMask,ButtonPressMask,KeyPressMask))

	gc = X11.XCreateGC(dis, win, 0, nil)

	X11.XSetWindowBackground(dis, win, 0x222222)
	X11.XClearWindow(dis, win)
	X11.XMapRaised(dis, win)
end

local function close_x()
	X11.XFreeGC(dis, gc);
	X11.XDestroyWindow(dis,win);
	X11.XCloseDisplay(dis);
	error();
end

local function redraw()
	X11.XClearWindow(dis, win);
	
	local shownleftright = 2
	local center = width / 2
	
	local x = (center - box_size / 2) - (box_size + padding) * shownleftright
	local y = padding
	local index_start = math.max(1, sel_app - shownleftright)
	local index_stop = math.min(#apps, sel_app + shownleftright, #apps) 
	
	for i = index_start, index_stop do
		if i < shownleftright then
			x = center - box_size / 2 - math.max(0 , sel_app - i) * (box_size + padding)
		end
		if i == sel_app then
			X11.XSetForeground(dis, gc, 0xFFDD11);
			X11.XDrawRectangle(dis, win, gc, x - padding, y - padding, (box_size + padding * 2) - 1, (box_size + padding * 2) - 1);
		else
			X11.XSetForeground(dis, gc, 0xFFFFFF);
			X11.XDrawRectangle(dis, win, gc, x, y, box_size, box_size);
		end
		X11.XDrawString(dis, win, gc, x + padding, y + box_size - padding, apps[i].name, #apps[i].name);
		x = x + box_size + padding
	end
end

local function main ()
	local event = ffi.new("XEvent")

	init_x()

	while(true) do
		X11.XNextEvent(dis, event)
		--Keypress
		if (event.type == 2) then
			local esc = 9
			local enter = 36
			local left = 113
			local right = 114
			local up = 111
			local down = 116
			
			local key_code = event.xkey.keycode
			
			if key_code == left then
				prev_application()
			elseif key_code == right then
				next_application()
			elseif key_code == enter then
				start_application()
				close_x()
			elseif key_code == esc then
				close_x()
			end
		end
		if (event.type) then
			redraw()
		end
	end
end

init_globals()
main()
