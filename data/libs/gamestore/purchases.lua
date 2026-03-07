local senders = require("gamestore.senders")
local purchases = {}

local sendStorePurchaseSuccessful = senders.sendStorePurchaseSuccessful
local sendRequestPurchaseData = senders.sendRequestPurchaseData
local sendUpdatedStoreBalances = senders.sendUpdatedStoreBalances

local function processItemPurchase(player, offerId, offerCount, movable, setOwner)
	local canReceive, errorMsg = player:canReceiveStoreItems(offerId, offerCount)
	if not canReceive then
		return error({ code = 0, message = errorMsg })
	end

	for t = 1, offerCount do
		player:addItemStoreInbox(offerId, offerCount or 1, movable, setOwner)
	end
end

local function processChargesPurchase(player, offerId, name, charges, movable, setOwner)
	local canReceive, errorMsg = player:canReceiveStoreItems(offerId, 1)
	if not canReceive then
		return error({ code = 0, message = errorMsg })
	end

	player:addItemStoreInbox(offerId, charges, movable, setOwner)
end

local function processSingleBlessingPurchase(player, blessId, count)
	player:addBlessing(blessId, count)
end

local function processAllBlessingsPurchase(player, count)
	local twistOfFateCount = player:getBlessingCount(1)

	if twistOfFateCount == 0 then
		player:addBlessing(1, count)
	elseif twistOfFateCount > 0 and twistOfFateCount < 5 then
		player:addBlessing(1, 5 - twistOfFateCount)
	end

	for i = 2, 8 do
		local currentCount = player:getBlessingCount(i)
		if currentCount < 5 then
			player:addBlessing(i, math.min(count, 5 - currentCount))
		end
	end
end

local function processInstantRewardAccess(player, offerCount)
	local limit = GameStore.ItemLimit.INSTANT_REWARD_ACCESS
	if player:getCollectionTokens() + offerCount >= limit + 1 then
		return error({ code = 1, message = "No puedes poseer mas de " .. limit .. " fichas de recompensa." })
	end
	player:setCollectionTokens(player:getCollectionTokens() + offerCount)
end

local function processCharmsPurchase(player)
	player:charmExpansion(true)
end

local function processPremiumPurchase(player, offerId)
	player:addPremiumDays(offerId - 3000)
	if configManager.getBoolean(configKeys.VIP_SYSTEM_ENABLED) then
		player:onAddVip(offerId - 3000)
	end
end

local function processStackablePurchase(player, offerId, offerCount, offerName, movable, setOwner)
	local canReceive, errorMsg = player:canReceiveStoreItems(offerId, offerCount)
	if not canReceive then
		return error({ code = 0, message = errorMsg })
	end

	local iType = ItemType(offerId)
	if not iType then
		return nil
	end

	local inbox = player:getStoreInbox()
	if inbox then
		local stackSize = iType:getStackSize()
		local remainingCount = offerCount
		while remainingCount > 0 do
			local countToAdd = math.min(remainingCount, stackSize)
			local inboxItem = inbox:addItem(offerId, countToAdd)
			if inboxItem then
				if not movable then
					inboxItem:setAttribute(ITEM_ATTRIBUTE_STORE, systemTime())
				end
			else
				return error({ code = 0, message = "Error al añadir el objeto al buzon de la tienda." })
			end
			remainingCount = remainingCount - countToAdd
		end
	end
end

local function processHouseRelatedPurchase(player, offer)
	local function isCaskItem(itemId)
		return (itemId >= ITEM_HEALTH_CASK_START and itemId <= ITEM_HEALTH_CASK_END) or (itemId >= ITEM_MANA_CASK_START and itemId <= ITEM_MANA_CASK_END) or (itemId >= ITEM_SPIRIT_CASK_START and itemId <= ITEM_SPIRIT_CASK_END)
	end

	local itemIds = offer.itemtype
	if type(itemIds) ~= "table" then
		itemIds = { itemIds }
	end

	local canReceive, errorMsg = player:canReceiveStoreItems(#itemIds)
	if not canReceive then
		return error({ code = 0, message = errorMsg })
	end

	local inbox = player:getStoreInbox()
	if inbox then
		for _, itemId in ipairs(itemIds) do
			if isCaskItem(itemId) then
				local decoKit = inbox:addItem(ITEM_DECORATION_KIT, 1)
				if decoKit then
					decoKit:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, "Has comprado este objeto en la Tienda.\nDesempaquetalo en tu casa para crear: <" .. ItemType(itemId):getName() .. ">.")
					decoKit:setCustomAttribute("unWrapId", itemId)
					decoKit:setAttribute(ITEM_ATTRIBUTE_DATE, offer.count)

					if not offer.movable then
						decoKit:setAttribute(ITEM_ATTRIBUTE_STORE, systemTime())
					end
				end
			else
				for i = 1, offer.count do
					local decoKit = inbox:addItem(ITEM_DECORATION_KIT, 1)
					if decoKit then
						decoKit:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, "Has comprado este objeto en la Tienda.\nDesempaquetalo en tu casa para crear: <" .. ItemType(itemId):getName() .. ">.")
						decoKit:setCustomAttribute("unWrapId", itemId)

						if not offer.movable then
							decoKit:setAttribute(ITEM_ATTRIBUTE_STORE, systemTime())
						end
					end
				end
			end
		end
		player:sendUpdateContainer(inbox)
	end
end

local function processOutfitPurchase(player, offerSexIdTable, addon)
	local looktype
	local _addon = addon and addon or 0

	if player:getSex() == PLAYERSEX_MALE then
		looktype = offerSexIdTable.male
	elseif player:getSex() == PLAYERSEX_FEMALE then
		looktype = offerSexIdTable.female
	end

	if not looktype then
		return error({ code = 0, message = "Este atuendo no es de tu genero, lo sentimos!" })
	elseif (not player:hasOutfit(looktype, 0)) and (_addon == 1 or _addon == 2) then
		return error({ code = 0, message = "Primero tienes que poseer el atuendo para poder comprar el complemento." })
	elseif player:hasOutfit(looktype, _addon) then
		return error({ code = 0, message = "Ya posees este atuendo." })
	else
		if not player:addOutfitAddon(looktype, _addon) or not player:hasOutfit(looktype, _addon) then
			error({ code = 0, message = "Ha ocurrido un error en la compra. Ha sido cancelada." })
		else
			player:addOutfitAddon(offerSexIdTable.male, _addon)
			player:addOutfitAddon(offerSexIdTable.female, _addon)
		end
	end
end

local function processMountPurchase(player, offerId)
	if player:hasMount(offerId) then
		return error({ code = 0, message = "Ya posees esta montura." })
	end

	player:addMount(offerId)
end

local function processNameChangePurchase(player, offer, productType, newName)
	if productType == GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_NAMECHANGE then
		local tile = Tile(player:getPosition())
		if tile then
			if not tile:hasFlag(TILESTATE_PROTECTIONZONE) then
				return error({ code = 1, message = "Solo puedes cambiarte el nombre en una Zona de Proteccion." })
			end
		end

		newName = newName:lower():trim():gsub("(%l)(%w*)", function(a, b)
			return string.upper(a) .. b
		end)

		local normalizedName = Game.getNormalizedPlayerName(newName, true)
		if normalizedName then
			return error({ code = 1, message = "Ese nombre esta en uso, prueba con otro!" })
		end

		local result = GameStore.canChangeToName(newName)
		if not result.ability then
			return error({ code = 1, message = result.reason })
		end

		local namelockReason = player:kv():get("namelock")
		local message
		if not namelockReason then
			player:makeCoinTransaction(offer)
			message = string.format("Has comprado %s por %d monedas.", offer.name, offer.price)
		else
			message = "Has cambiado el nombre de tu personaje."
		end
		addPlayerEvent(sendStorePurchaseSuccessful, 500, player:getId(), message)

		player:changeName(newName)
	else
		return addPlayerEvent(sendRequestPurchaseData, 250, player:getId(), offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_NAMECHANGE)
	end
end

local function processSexChangePurchase(player)
	player:toggleSex()
end

local function processExpBoostPurchase(player)
	local currentXpBoostTime = player:getXpBoostTime()
	player:setXpBoostPercent(50)
	player:setXpBoostTime(currentXpBoostTime + 3600)
end

local function processPreyThirdSlot(player)
	if player:preyThirdSlot() then
		return error({ code = 1, message = "Ya has desbloqueado todas las ranuras de criatura." })
	end
	player:preyThirdSlot(true)
end

local function processTaskHuntingThirdSlot(player)
	if player:taskHuntingThirdSlot() then
		return error({ code = 1, message = "Ya tienes todas las ranuras de caza." })
	end
	player:taskHuntingThirdSlot(true)
end

local function processPreyBonusReroll(player, offerCount)
	local limit = GameStore.ItemLimit.PREY_WILDCARD
	if player:getPreyCards() + offerCount >= limit + 1 then
		return error({ code = 1, message = "No puedes poseer mas de " .. limit .. " cartas de criatura." })
	end
	player:addPreyCards(offerCount)
end

local function processTempleTeleportPurchase(player)
	local inPz = player:getTile():hasFlag(TILESTATE_PROTECTIONZONE)
	local inFight = player:isPzLocked() or player:getCondition(CONDITION_INFIGHT, CONDITIONID_DEFAULT)
	if not inPz and inFight then
		return error({ code = 0, message = "No puedes usar el teleport al templo cuando si estas bajo amenaza." })
	end

	player:teleportTo(player:getTown():getTemplePosition())
	player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Has sido teletransportado a tu ciudad.")
end

local function processHirelingPurchase(player, offer, productType, hirelingName, chosenSex)
	if player:getClient().version < 1200 then
		return error({ code = 1, message = "No puedes contratar mayordomos en esta version, no estas usando un cliente adecuado." })
	end

	if productType == GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_HIRELING then
		local result = GameStore.canUseHirelingName(hirelingName)
		if not result.ability then
			return error({ code = 1, message = result.reason })
		end

		hirelingName = hirelingName:lower():gsub("(%l)(%w*)", function(a, b)
			return string.upper(a) .. b
		end)

		local hireling = player:addNewHireling(hirelingName, chosenSex)
		if not hireling then
			return error({ code = 1, message = "Error al entregar tu lampara de mayordomo, intentalo mas tarde." })
		end

		player:makeCoinTransaction(offer, hirelingName)
		local message = "Has comprado " .. hirelingName
		player:createTransactionSummary(offer.type, 1)
		return addPlayerEvent(sendStorePurchaseSuccessful, 650, player:getId(), message)
		-- If not, we ask him to do!
	else
		if player:getHirelingsCount() >= GameStore.ItemLimit.HIRELING then
			return error({ code = 1, message = "No puedes poseer mas de " .. GameStore.ItemLimit.HIRELING .. " mayordomos." })
		end
		-- TODO: Use the correct dialog (byte 0xDB) on client 1205+
		-- for compatibility, request name using the change name dialog
		return addPlayerEvent(sendRequestPurchaseData, 250, player:getId(), offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_HIRELING)
	end
end

-- Hireling Helpers
local function HandleHirelingNameChange(playerId, offer, newHirelingName)
	local player = Player(playerId)
	if not player then
		return
	end

	local functionCallback = function(playerIdInFunction, data, hireling)
		local playerInFunction = Player(playerIdInFunction)
		if not playerInFunction then
			return
		end

		if not hireling then
			return playerInFunction:showInfoModal("Error", "Tienes que seleccionar un mayordomo.")
		end

		if hireling.active > 0 then
			return playerInFunction:showInfoModal("Error", "Tu mayordomo tiene que estar dentro de su lampara.")
		end

		local oldName = hireling.name
		hireling.name = data.newHirelingName

		if not playerInFunction:makeCoinTransaction(data.offer, oldName .. " a " .. hireling.name) then
			return playerInFunction:showInfoModal("Error", "Error en la Transaccion")
		end

		local lamp = playerInFunction:findHirelingLamp(hireling:getId())
		if lamp then
			lamp:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, "Esta lampara misteriosa hace invocar a tu propio mayordomo.\nEste objeto no puede ser comerciado.\nEsta lampara pertenece a " .. hireling:getName() .. ".")
		end
		logger.debug("{} ha sido renombrado a {}", oldName, hireling.name)
		sendUpdatedStoreBalances(playerIdInFunction)
	end

	player:sendHirelingSelectionModal("Selecciona un Mayordomo", "Selecciona a un Mayordomo", functionCallback, { offer = offer, newHirelingName = newHirelingName })
end

local function processHirelingChangeNamePurchase(player, offer, productType, newHirelingName)
	if player:getClient().version < 1200 then
		return error({
			code = 1,
			message = "You cannot buy hireling change name on client 10, please relog on client 12 and try again.",
		})
	end

	if productType == GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_NAMECHANGE then
		local result = GameStore.canUseHirelingName(newHirelingName)
		if not result.ability then
			return error({ code = 1, message = result.reason })
		end

		newHirelingName = newHirelingName:lower():gsub("(%l)(%w*)", function(a, b)
			return string.upper(a) .. b
		end)

		local message = "Close the store window to select which hireling should be renamed to " .. newHirelingName
		local playerId = player:getId()
		addPlayerEvent(sendStorePurchaseSuccessful, 200, playerId, message)
		addPlayerEvent(HandleHirelingNameChange, 550, playerId, offer, newHirelingName)
	else
		return addPlayerEvent(sendRequestPurchaseData, 250, player:getId(), offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_NAMECHANGE)
	end
end

local function HandleHirelingSexChange(playerId, offer)
	local player = Player(playerId)
	if not player then
		return
	end

	local functionCallback = function(playerIdInFunction, data, hireling)
		local playerInFunction = Player(playerIdInFunction)
		if not playerInFunction then
			return
		end

		if not hireling then
			return playerInFunction:showInfoModal("Error", "Your must select a hireling.")
		end

		if hireling.active > 0 then
			return playerInFunction:showInfoModal("Error", "Your hireling must be inside his/her lamp.")
		end

		if not playerInFunction:makeCoinTransaction(data.offer, hireling:getName()) then
			return playerInFunction:showInfoModal("Error", "Transaction error")
		end

		local changeTo, sexString, lookType
		if hireling.sex == HIRELING_SEX.FEMALE then
			changeTo = HIRELING_SEX.MALE
			sexString = "male"
			lookType = HIRELING_OUTFIT_DEFAULT.male
		else
			changeTo = HIRELING_SEX.FEMALE
			sexString = "female"
			lookType = HIRELING_OUTFIT_DEFAULT.female
		end

		hireling.sex = changeTo
		hireling.looktype = lookType

		logger.debug("{} sex was changed to {}", hireling:getName(), sexString)
		sendUpdatedStoreBalances(playerIdInFunction)
	end

	player:sendHirelingSelectionModal("Choose a Hireling", "Select a hireling below", functionCallback, { offer = offer })
end

local function processHirelingChangeSexPurchase(player, offer)
	if player:getClient().version < 1200 then
		return error({
			code = 1,
			message = "You cannot buy hireling change sex on client 10, please relog on client 12 and try again.",
		})
	end

	local message = "Close the store window to select which hireling should have the sex changed."
	local playerId = player:getId()
	addPlayerEvent(sendStorePurchaseSuccessful, 200, playerId, message)
	addPlayerEvent(HandleHirelingSexChange, 550, playerId, offer)
end

local function processHirelingSkillPurchase(player, offer)
	if player:getClient().version < 1200 then
		return error({
			code = 1,
			message = "You cannot buy hireling skill on client 10, please relog on client 12 and try again.",
		})
	end

	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
	player:enableHirelingSkill(GetHirelingSkillNameById(offer.id))
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "A new hireling skill has been added to all your hirelings")
end

local function processHirelingOutfitPurchase(player, offer)
	if player:getClient().version < 1200 then
		return error({
			code = 1,
			message = "You cannot buy hireling outfit on client 10, please relog on client 12 and try again.",
		})
	end

	local outfitName = GetHirelingOutfitNameById(offer.id)
	logger.debug("Processing hireling outfit purchase name {}", outfitName)
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)
	player:enableHirelingOutfit(outfitName)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "A new hireling outfit has been added to all your hirelings")
end

purchases.processItemPurchase = processItemPurchase
purchases.processChargesPurchase = processChargesPurchase
purchases.processSingleBlessingPurchase = processSingleBlessingPurchase
purchases.processAllBlessingsPurchase = processAllBlessingsPurchase
purchases.processInstantRewardAccess = processInstantRewardAccess
purchases.processCharmsPurchase = processCharmsPurchase
purchases.processPremiumPurchase = processPremiumPurchase
purchases.processStackablePurchase = processStackablePurchase
purchases.processHouseRelatedPurchase = processHouseRelatedPurchase
purchases.processOutfitPurchase = processOutfitPurchase
purchases.processMountPurchase = processMountPurchase
purchases.processNameChangePurchase = processNameChangePurchase
purchases.processSexChangePurchase = processSexChangePurchase
purchases.processExpBoostPurchase = processExpBoostPurchase
purchases.processPreyThirdSlot = processPreyThirdSlot
purchases.processTaskHuntingThirdSlot = processTaskHuntingThirdSlot
purchases.processPreyBonusReroll = processPreyBonusReroll
purchases.processTempleTeleportPurchase = processTempleTeleportPurchase
purchases.processHirelingPurchase = processHirelingPurchase
purchases.processHirelingChangeNamePurchase = processHirelingChangeNamePurchase
purchases.processHirelingChangeSexPurchase = processHirelingChangeSexPurchase
purchases.processHirelingSkillPurchase = processHirelingSkillPurchase
purchases.processHirelingOutfitPurchase = processHirelingOutfitPurchase

return purchases
