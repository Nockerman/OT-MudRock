local CHANNEL_HELP = 7

local muted = Condition(CONDITION_CHANNELMUTEDTICKS, CONDITIONID_DEFAULT)
muted:setParameter(CONDITION_PARAM_SUBID, CHANNEL_HELP)
muted:setParameter(CONDITION_PARAM_TICKS, 3600000)

function onSpeak(player, type, message)
	local playerGroupType = player:getGroup():getId()
	if player:getLevel() == 1 and playerGroupType == GROUP_TYPE_NORMAL then
		player:sendCancelMessage("No puedes hablar en este canal hasta ser nivel 1.")
		return false
	end

	local hasExhaustion = player:kv():get("channel-help-exhaustion") or 0
	if hasExhaustion > os.time() then
		player:sendCancelMessage("Has sido silenciado del Canal de Ayuda por uso inapropiado.")
		return false
	end

	if playerGroupType >= GROUP_TYPE_TUTOR then
		if string.sub(message, 1, 6) == "!callar " then
			local targetName = string.sub(message, 7)
			local target = Player(targetName)
			if target then
				if playerGroupType > target:getAccountType() then
					if not target:getCondition(CONDITION_CHANNELMUTEDTICKS, CONDITIONID_DEFAULT, CHANNEL_HELP) then
						target:addCondition(muted)
						target:kv():set("channel-help-exhaustion", os.time() + 180) -- 3 minutes
						sendChannelMessage(CHANNEL_HELP, TALKTYPE_CHANNEL_R1, target:getName() .. " ha sido silenciado por " .. player:getName() .. " por un uso inapropiado del canal.")
					else
						player:sendCancelMessage("Ese ciudadano ya esta silenciado.")
					end
				else
					player:sendCancelMessage("No estas autorizado para silenciar a otro ciudadano.")
				end
			else
				player:sendCancelMessage(RETURNVALUE_PLAYERWITHTHISNAMEISNOTONLINE)
			end
			return false
		elseif string.sub(message, 1, 8) == "!hablar " then
			local targetName = string.sub(message, 9)
			local target = Player(targetName)
			if target then
				if playerGroupType > target:getAccountType() then
					local hasExhaustionTarget = target:kv():get("channel-help-exhaustion") or 0
					if hasExhaustionTarget > os.time() then
						target:removeCondition(CONDITION_CHANNELMUTEDTICKS, CONDITIONID_DEFAULT, CHANNEL_HELP)
						sendChannelMessage(CHANNEL_HELP, TALKTYPE_CHANNEL_R1, target:getName() .. " ya puede volver a hablar.")
						target:kv():remove("channel-help-exhaustion")
					else
						player:sendCancelMessage("Ese ciudadano no esta silenciado.")
					end
				else
					player:sendCancelMessage("No estas autorizado para permitirle hablar a otro ciudadano.")
				end
			else
				player:sendCancelMessage(RETURNVALUE_PLAYERWITHTHISNAMEISNOTONLINE)
			end
			return false
		end
	end

	if type == TALKTYPE_CHANNEL_Y then
		if playerGroupType >= GROUP_TYPE_TUTOR or player:hasFlag(PlayerFlag_TalkOrangeHelpChannel) then
			type = TALKTYPE_CHANNEL_O
		end
	elseif type == TALKTYPE_CHANNEL_O then
		if playerGroupType < GROUP_TYPE_TUTOR and not player:hasFlag(PlayerFlag_TalkOrangeHelpChannel) then
			type = TALKTYPE_CHANNEL_Y
		end
	elseif type == TALKTYPE_CHANNEL_R1 then
		if playerGroupType < GROUP_TYPE_GAMEMASTER and not player:hasFlag(PlayerFlag_CanTalkRedChannel) then
			if playerGroupType >= GROUP_TYPE_TUTOR or player:hasFlag(PlayerFlag_TalkOrangeHelpChannel) then
				type = TALKTYPE_CHANNEL_O
			else
				type = TALKTYPE_CHANNEL_Y
			end
		end
	end
	return type
end
