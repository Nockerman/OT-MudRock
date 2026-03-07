function onSpeak(player, type, message)
	if player:getLevel() < 50 and not player:isPremium() and not player:isPremium() then
		player:sendCancelMessage("No puedes hablar en este canal hasta haber alcanzado el nivel 50, o poseas el estatus de noble.")
		return false
	end

	local playerGroupType = player:getGroup():getId()
	if type == TALKTYPE_CHANNEL_Y then
		if playerGroupType >= GROUP_TYPE_GAMEMASTER then
			type = TALKTYPE_CHANNEL_O
		end
	elseif type == TALKTYPE_CHANNEL_O then
		if playerGroupType < GROUP_TYPE_GAMEMASTER then
			type = TALKTYPE_CHANNEL_Y
		end
	elseif type == TALKTYPE_CHANNEL_R1 then
		if playerGroupType < GROUP_TYPE_GAMEMASTER and not player:hasFlag(PlayerFlag_CanTalkRedChannel) then
			type = TALKTYPE_CHANNEL_Y
		end
	end
	return type
end
