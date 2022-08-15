
music={}


music.pause_between_songs=tonumber(minetest.settings:get("music_pause_between_songs")) or 4

--end config

music.modpath=minetest.get_modpath("music")
if not music.modpath then
	error("music mod folder has to be named 'music'!")
end
--{name, length, gain~1}
music.songs = {}
local sfile, sfileerr=io.open(music.modpath..DIR_DELIM.."songs.txt")
if not sfile then error("Error opening songs.txt: "..sfileerr) end
for linent in sfile:lines() do
	-- trim leading and trailing spaces away
	local line = string.match(linent, "^%s*(.-)%s*$")
	if line~="" and string.sub(line,1,1)~="#" then
		local name, timeMinsStr, timeSecsStr, gainStr, title = string.match(line, "^(%S+)%s+(%d+):([%d%.]+)%s+([%d%.]+)%s*(.*)$")
		local timeMins, timeSecs, gain = tonumber(timeMinsStr), tonumber(timeSecsStr), tonumber(gainStr)
		if title=="" then title = name end
		if name and timeMins and timeSecs and gain then
			music.songs[#music.songs+1]={name=name, length=timeMins*60+timeSecs, lengthhr=timeMinsStr..":"..timeSecsStr, gain=gain, title=title}
		else
			minetest.log("warning", "[music] Misformatted song entry in songs.txt: "..line)
		end
	end
end
sfile:close()

if #music.songs==0 then
	print("[music]no songs registered, not doing anything")
	return
end

music.storage = minetest.get_mod_storage()

music.handles={}

music.playing=false
music.id_playing=nil
music.song_time_left=nil
music.time_next=10 --sekunden
music.id_last_played=nil

minetest.register_globalstep(function(dtime)
	if music.playing then
		if music.song_time_left<=0 then
			music.stop_song()
			music.time_next=music.pause_between_songs
		else
			music.song_time_left=music.song_time_left-dtime
		end
	elseif music.time_next then
		if music.time_next<=0 then
			music.next_song()
		else
			music.time_next=music.time_next-dtime
		end
	end
end)
music.play_song=function(id)
	if music.playing then
		music.stop_song()
	end
	local song=music.songs[id]
	if not song then return end
	for _,player in ipairs(minetest.get_connected_players()) do
		local pname=player:get_player_name()
		local pvolume=tonumber(music.storage:get_string("vol_"..pname))
		if not pvolume then pvolume=1 end
		if pvolume>0 then
			local handle = minetest.sound_play(song.name, {to_player=pname, gain=song.gain*pvolume})
			if handle then
				music.handles[pname]=handle
			end
		end
	end
	music.playing=id
	--adding 2 seconds as security
	music.song_time_left = song.length + 2
end
music.stop_song=function()
	for pname, handle in pairs(music.handles) do
		minetest.sound_stop(handle)
	end
	music.id_last_played=music.playing
	music.playing=nil
	music.handles={}
	music.time_next=nil
end

music.next_song=function()
	local next
	repeat
		next=math.random(1,#music.songs)
	until #music.songs==1 or next~=music.id_last_played
	music.play_song(next)
end

music.song_human_readable=function(id)
	if not tonumber(id) then return "<error>" end
	local song=music.songs[id]
	if not song then return "<error>" end
	return id..": "..song.title.." ["..song.lengthhr.."]"
end

minetest.register_privilege("music", "may control the music player daemon (music) mod")

minetest.register_chatcommand("music_stop", {
	params = "",
	description = "Stop the song currently playing",
	privs = {music=true},
	func = function(name, param)
		music.stop_song()
	end,		
})
minetest.register_chatcommand("music_list", {
	params = "",
	description = "List all available songs and their IDs",
	privs = {music=true},
	func = function(name, param)
		for k,v in ipairs(music.songs) do
			minetest.chat_send_player(name, music.song_human_readable(k))
		end
	end,		
})
minetest.register_chatcommand("music_play", {
	params = "<id>",
	description = "Play the songs with the given ID (see ids with /music_list)",
	privs = {music=true},
	func = function(name, param)
		if param=="" then
			music.next_song()
			return true,"Playing: "..music.song_human_readable(music.playing)
		end
		id=tonumber(param)
		if id and id>0 and id<=#music.songs then
			music.play_song(id)
			return true,"Playing: "..music.song_human_readable(id)
		end
		return false, "Invalid song ID!"
	end,		
})
minetest.register_chatcommand("music_what", {
	params = "",
	description = "Display the currently played song.",
	privs = {music=true},
	func = function(name, param)
		if not music.playing then
			if music.time_next and music.time_next~=0 then
				return true,"Nothing playing, "..math.floor(music.time_next or 0).." sec. left until next song."
			else
				return true,"Nothing playing."
			end
		end
		return true,"Playing: "..music.song_human_readable(music.playing).."\nTime Left: "..math.floor(music.song_time_left or 0).." sec."
	end,		
})
minetest.register_chatcommand("music_next", {
	params = "[seconds]",
	description = "Start the next song, either immediately (no parameters) or after n seconds.",
	privs = {music=true},
	func = function(name, param)
		music.stop_song()
		if param and tonumber(param) then
			music.time_next=tonumber(param)
			return true,"Next song in "..param.." seconds!"
		else
			music.next_song()
			return true,"Next song started!"
		end
	end,		
})
minetest.register_chatcommand("mvolume", {
	params = "[volume level (0-1)]",
	description = "Set your background music volume. Use /mvolume 0 to turn off background music for you. Without parameters, show your current setting.",
	privs = {},
	func = function(pname, param)
		if not param or param=="" then
			local pvolume=tonumber(music.storage:get_string("vol_"..pname))
			if not pvolume then pvolume=0.5 end
			if pvolume>0 then
				return true, "Your music volume is set to "..pvolume.."."
			else
				if music.handles[pname] then
					minetest.sound_stop(music.handles[pname])
				end
				return true, "Background music is disabled for you. Use '/mvolume 1' to enable it again."
			end
		end
		local pvolume=tonumber(param)
		if not pvolume then
			return false, "Invalid usage: /mvolume [volume level (0-1)]"
		end
		pvolume = math.min(pvolume, 1)
		pvolume = math.max(pvolume, 0)
		music.storage:set_string("vol_"..pname, pvolume)
		if pvolume>0 then
			return true, "Music volume set to "..pvolume..". Change will take effect when the next song starts."
		else
			if music.handles[pname] then
				minetest.sound_stop(music.handles[pname])
			end
			return true, "Disabled background music for you. Use /mvolume to enable it again."
		end
	end,		
})

if vote then
	dofile(music.modpath..DIR_DELIM.."vote.lua")
end
