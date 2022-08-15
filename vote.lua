--music
--vote.lua - vote module to change songs

function music.vote_play(name, param)
	id=tonumber(param)
	if id and id>0 and id<=#music.songs then
		vote.new_vote(name, {
			description = "Play "..music.song_human_readable(id),
			help = "/yes or /no",
			duration = 20,
			perc_needed = 0.4,

			on_result = function(self, result, results)
				if result == "yes" then
					minetest.chat_send_all("Vote to play " .. music.song_human_readable(id) .. " passed " ..
							#results.yes .. " to " .. #results.no)
					music.play_song(id)
				else
					minetest.chat_send_all("Vote to play " .. music.song_human_readable(id) .. " failed " ..
							#results.yes .. " to " .. #results.no)
				end
			end,

			on_vote = function(self, name, value)
				minetest.chat_send_all(name .. " voted " .. value .. " to '" ..
						self.description .. "'")
			end,
		})
		return true
	end
	return false,"Invalid song ID! See available song IDs using /music_list"
end

minetest.register_chatcommand("vote_music_play", {
	func = music.vote_play
})

function music.vote_next(name, param)
	vote.new_vote(name, {
		description = "Play next song",
		help = "/yes or /no",
		duration = 20,
		perc_needed = 0.4,

		on_result = function(self, result, results)
			minetest.chat_send_all(result..dump(results))
			if result == "yes" then
				minetest.chat_send_all("Vote to play next song passed " ..
						#results.yes .. " to " .. #results.no)
				music.next_song()
			else
				minetest.chat_send_all("Vote to play next song failed " ..
						#results.yes .. " to " .. #results.no)
			end
		end,

		on_vote = function(self, name, value)
			minetest.chat_send_all(name .. " voted " .. value .. " to '" ..
					self.description .. "'")
		end
	})
	return true
end

minetest.register_chatcommand("vote_music_next", {
	func = music.vote_next
})

