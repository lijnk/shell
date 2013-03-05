-- lua parts of the os api

function os.version()
  return "Shell 0.1"
end

function os.pullEventRaw(_filter)
  return coroutine.yield(_filter)
end

function os.pullEvent(_filter)
  local event = {os.pullEventRaw(_filter)}
  if event[1] == "terminate" then
    error("Terminated", 0)
  end
  return unpack(event)
end

-- globals

function sleep(_time)
  local timer = os.startTimer(_time)
  repeat
    local event, p1 = os.pullEvent("timer")
  until p1 == timer
end

function write(text)
  local w, h = term.getSize()
  local x, y = term.getCursorPos()
  local lines = 0
  
  local function newLine()
    if y + 1 <= h then
      term.setCursorPos(1, y + 1)
    else
      term.scroll(1)
      term.setCursorPos(1, h)
    end
    x, y = term.getCursorPos()
    lines = lines + 1
  end

  while string.len(text) > 0 do
    --whitespace
    local ws = string.match(text, "^[ \t]+")
    if ws then
      term.write(ws)
      x, y = term.getCursorPos()
      text = string.sub(text, string.len(ws) + 1)
    end

    --newlines
    local nl = string.match(text, "^\n")
    if nl then
      newLine()
      text = string.sub(text, 2)
    end

    --regular text
    local t = string.match(text, "^[^ \t\n]+")
    if t then
      text = string.sub(text, string.len(t) + 1)
      --multiline text
      if string.len(t) > w then
        while string.len(t) > 0 do
	  if x > w then
	    newLine()
	  end
	  term.write(t)
	  t = string.sub(t, (w-x) + 2)
	  x, y = term.getCursorPos()
	end
      else
      --regular sized text
        if x + string.len(t) - 1 > w then
	  newLine()
	end
	term.write(t)
	x, y = term.getCursorPos()
      end
    end
  end

  return lines
end

function print(...)
  local lines = 0
  for i, v in ipairs({...}) do
    lines = lines + write(tostring(v))
  end
  lines = lines + write("\n")
  return lines
end

function printError(...)
  if term.isColor() then
    term.setTextColor(colors.red)
  end
  print(...)
  term.setTextColor(colors.white)
end

function read(_repl, _hist, _line)
  term.setCursorBlink(true)
  local line = _line or ""
  local histPos = nil
  local pos = 0
  if _repl then
    _repl = string.sub(_repl, 1, 1)
  end
  
  local w, h = term.getSize()
  local x, y = term.getCursorPos()

  local function redraw(_r)
    local scroll = 0
    if x + pos >= w then
      scroll = (x+pos) - w
    end

    term.setCursorPos(x, y)
    local tmp = _r or _repl
    if tmp then
      term.write(string.rep(tmp, string.len(line) - scroll))
    else
      term.write(string.sub(line, scroll + 1))
    end
    term.setCursorPos(x + pos - scroll, y)
  end

  if line ~= "" then
    pos = string.len(line)
    redraw()
  end
  local tabs = false
  while true do
    local event, p1 = os.pullEvent()
    --plug something for tab complete here?
    if event == "char" then
      line = string.sub(line, 1, pos) .. p1 .. string.sub(line, pos + 1)
      pos = pos + 1
      redraw()
    elseif event == "key" then
      if p1 == keys.enter then
        --enter
	break
      elseif p1 == keys.tab then
        --tab
	line = line .. "\t"
        tabs = true
	break
      elseif p1 == keys.left then
        --left
	if pos > 0 then
	  pos = pos - 1
	  redraw()
	end
      elseif p1 == keys.right then
        --right
	if pos < string.len(line) then
	  pos = pos + 1
	  redraw()
	end
      elseif p1 == keys.up or p1 == keys.down then
        --up/down
	if _hist then
	  redraw(" ")
	  if p1 == keys.up then
	    if histPos == nil then
	      if #_hist > 0 then
	        histPos = #_hist
              end
	    elseif histPos > 1 then
	      histPos = histPos - 1
	    end
	  else
	    if histPos == #_hist then
	      histPos = nil
	    elseif histPos ~= nil then
	      histPos = histPos + 1
	    end
	  end

	  if histPos then
	    line = _hist[histPos]
	    pos = string.len(line)
	  else
	    line = ""
	    pos = 0
	  end
	  redraw()
	end
      elseif p1 == keys.backspace then
        --backspace
	if pos > 0 then
	  redraw(" ")
	  line = string.sub(line, 1, pos - 1) .. string.sub(line, pos + 1)
	  pos = pos - 1
	  redraw()
	end
      elseif p1 == keys.home then
        --home
	pos = 0
	redraw()
      elseif p1 == keys.delete then
        --delete
	if pos < string.len(line) then
	  redraw(" ")
	  line = string.sub(line, 1, pos) .. string.sub(line, pos + 2)
	  redraw()
	end
      elseif p1 == keys["end"] then
        --end
	pos = string.len(line)
	redraw()
      end
    end
  end
  
  term.setCursorBlink(false)
  if not tabs then
    term.setCursorPos(w + 1, y)
    print()
  else
    term.setCursorPos(x, y)
  end
  return line
end

loadfile = function(file)
  local f = fs.open(file, "r")
  if file then
    local fn, err = loadstring(f.readAll(), fs.getName(file))
    f.close()
    return fn, err
  end
  return nil, "File not found"
end

dofile = function(file)
  local fn, err = loadfile(file)
  if fn then
    setfenv(fn, getfenv(2))
    return fn
  else
    error(err, 2)
  end
end

--install rest of os api

function os.run(_env, _path, ...)
  local args = {...}
  local fn, err = loadfile(_path)
  if fn then
    local env = _env
    setmetatable(env, {__index = _G})
    setfenv(fn, env)
    local ok, err = pcall(function ()
      fn(unpack(args))
    end)

    if not ok then
      if err and err ~= "" then
        printError(err)
      end
      return false
    end
    return true
  end
  if err and err ~= "" then
    printError(err)
  end
  return false
end

local nativegetmetatable = getmetatable
local nativetype = type
local nativeerror = error

function getmetatable(_t)
  if nativetype(_t) == "string" then
    nativeerror("Attempt to access string metatable", 2)
    return nil
  end
  return nativegetmetatable(_t)
end

local APIsLoading = {}

function os.loadAPI(_path)
  local name = fs.getName(_path)
  if APIsLoading[name] then
    printError("API " ..name.. " is already being loaded")
    return false
  end
  APIsLoading[name] = true

  local env = {}
  setmetatable(env, {__index = _G})
  local APIFunc, err = loadfile(_path)
  if APIFunc then
    setfenv(APIFunc, env)
    APIFunc()
  else
    printError(err)
    APIsLoading[name] = nil
    return false
  end

  local API = {}
  for k, v in pairs(env) do
    API[k] = v
  end

  _G[name] = API
  APIsLoading[name] = nil
  return true
end

function os.sleep(t)
  sleep(t)
end

local nativeshutdown = os.shutdown

function os.shutdown()
  nativeshutdown()
  while true do
    coroutine.yield()
  end
end

local nativereboot = os.reboot

function os.reboot()
  nativereboot()
  while true do
    coroutine.yield()
  end
end

--install lua for HTTP API (if enabled)
if http then
  local function wrapRequest(_url, _post)
    local requestID = http.request(_url, _post)
    while true do
      local event, p1, p2 = os.pullEvent()
      if event == "http_success" and p1 == _url then
        return p2
      elseif event == "http_failure" and p1 == _url then
        return nil
      end
    end
  end

  http.get = function(_url)
    return wrapRequest(_url, nil)
  end

  http.post = function(_url, _post)
    return wrapRequest(_url, _post or "")
  end
end

--install lua for peripheral API
peripheral.wrap = function(side)
  if peripheral.isPresent(side) then
    local methods = peripheral.getMethods(side)
    local result = {}
    for i, v in ipairs(methods) do
      result[v] = function(...)
        return peripheral.call(side, v, ...)
      end
    end
    return result
  end
  return nil
end

--load APIs
local APIs = fs.list("rom/apis")
for i,v in ipairs(APIs) do
  if string.sub(v, 1, 1) ~= "." then
    local path = fs.combine("rom/apis", v)
    if not fs.isDir(path) then
      os.loadAPI(path)
    end
  end
end

if turtle then
  local APIs = fs.list("rom/apis/turtle")
  for i,v in ipairs(APIs) do
    if string.sub(v, 1, 1) ~= "." then
      local path = fs.combine("rom/apis/turtle", v)
      if not fs.isDir(path) then
        os.loadAPI(path)
      end
    end
  end
end

--start shell
local ok, err = pcall(function()
  parallel.waitForAny(
    function()
      os.run({}, "rom/programs/shell")
    end,
    function()
      rednet.run()
    end
  )
end)

if not ok then
  printError(err)
end

pcall(function()
  term.setCursorBlink(false)
  print("Press any key to continue...")
  os.pullEvent("key")
end)

os.shutdown()

