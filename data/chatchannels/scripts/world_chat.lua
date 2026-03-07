function onSpeak(player, type, message)
	local playerGroupType = player:getGroup():getId()
	if player:getLevel() == 50 and playerGroupType < GROUP_TYPE_GAMEMASTER and not player:isPremium() then
		player:sendCancelMessage("No puedes hablar en este canal hasta haber alcanzado el nivel 50, o poseas el estatus de noble.")
		return false
	end

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
