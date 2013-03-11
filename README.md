Some shell I'm working on for computercraft.

To install, get a fresh `mods/ComputerCraft/lua` folder and replace the files with the files using my lua folder (ie: my lua/bios.lua replaces their lua/bios.lua)

Sync command:
Usage: sync [get] [send &lt;path&gt;]

get: will download the files from whatever terminal is at send  
send &lt;path&gt;: waits for a get request. If a folder is specified, then it'll recursively grab all contents within it. Multiple paths can be specified and are separated by a space. Sending computer must be named host in order for computers using "get" to listen.
