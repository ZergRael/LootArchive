local addonName = "LootArchive"
local addonTitle = select(2, GetAddOnInfo(addonName))
local addonVersion = GetAddOnMetadata(addonName, "Version")
local LA = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceComm-3.0", "AceSerializer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local libDBIcon = LibStub("LibDBIcon-1.0")

-- Addon init
function LA:OnInitialize()
    -- Addon savedvariables database
    self.db = LibStub("AceDB-3.0"):New(addonName, {
        profile = {
            minimapButton = {
                hide = false,
            },
            announceTo = "RAID_WARNING",
            callLootStr = L["Roll for %s"],
            awardStr = L["%s awarded to %s"],
            maxHistory = 300,
        },
        factionrealm = {
            history = {},
        },
    })

    -- Addon session variables
    self.currentGuild = nil
    self.currentGuildRank = nil
    self.trackedItem = nil

    -- This is not usable at this point, we need to wait for PLAYER_GUILD_UPDATE to fetch guild info
    -- self:FetchCurrentGuild()

    -- Events register
    self:RegisterEvent("LOOT_OPENED")
    -- self:RegisterEvent("CHAT_MSG_LOOT")
    self:RegisterEvent("OPEN_MASTER_LOOT_LIST")
    self:RegisterEvent("PLAYER_GUILD_UPDATE")

    -- Hooks
    self:Hook("GiveMasterLoot", true)

    self:RegisterComm(addonName, "ReceiveSyncDB")

    -- GUI and options init
	self:DrawMinimapIcon()
    self:RegisterOptionsTable()
end

-- EVENT HANDLERS
-- This could be used to trigger something in raids
-- probably useless but I like this event
function LA:LOOT_OPENED(eventName)
    -- self:Print("LOOT_OPENED")
end

-- Required to get player current guild after login
function LA:PLAYER_GUILD_UPDATE(eventName, unitTarget)
    -- self:Print("PLAYER_GUILD_UPDATE", unitTarget)
    if unitTarget == "player" then
        self:FetchCurrentGuild()
    end
end

-- This is spammy
function LA:CHAT_MSG_LOOT(eventName)
    self:Print("CHAT_MSG_LOOT")
end

-- Probably not needed
function LA:OPEN_MASTER_LOOT_LIST(eventName)
    self:Print("OPEN_MASTER_LOOT_LIST")
end

-- Hook on ML distribution to ease recording
function LA:GiveMasterLoot(slotId, candidateId, ...)
    local candidate = tostring(GetMasterLootCandidate(candidateId))
    local itemLink = tostring(GetLootSlotLink(slotId))
    self:Print("GiveMasterLoot", itemLink, candidate)

    self:GetItemMixin(itemLink, function(item)
        self:Award(item, candidate)
    end)
end

function LA:Award(itemMixin, playerName)
    self:Announce(format(self.db.profile.awardStr, itemMixin:GetItemLink(), playerName))
    self:StoreLootAwarded(itemMixin:GetItemID(), playerName)
end

-- Async function to retrieve itemMixin from item id or link
function LA:GetItemMixin(itemIdOrLink, callbackFn)
    if not itemIdOrLink or not callbackFn then
        return
    end

    -- Get real ID
    local id = GetItemInfoInstant(itemIdOrLink)
    if not id then
        self:Print("This does not seem to be a known valid item : ", itemIdOrLink)
        return
    end

    if tostring(id) == itemIdOrLink then
        self:Print("This seems to be an item id : ", itemIdOrLink)
        local itemMixin = Item:CreateFromItemID(itemIdOrLink)
        itemMixin:ContinueOnItemLoad(function()
            callbackFn(itemMixin)
        end)
    else
        self:Print("This seems to be an item link : ", itemIdOrLink)
        local itemMixin = Item:CreateFromItemLink(itemIdOrLink)
        itemMixin:ContinueOnItemLoad(function()
            callbackFn(itemMixin)
        end)
    end
end

-- Start tracking item from console item link
function LA:AddFromConsole(itemIdOrLink)
    self:Print("AddFromConsole", itemIdOrLink)
    if not itemIdOrLink then
        return
    end

    self:GetItemMixin(itemIdOrLink, function(item)
        LA:TrackItem(item)
    end)
end

-- Announce and start tracking item for later award process
function LA:TrackItem(itemMixin)
    self:Print("TrackItem", itemMixin:GetItemName())

    local itemLink = itemMixin:GetItemLink()

    -- Announce
    self:Announce(format(self.db.profile.callLootStr, itemLink))

    -- Store id for manual distribution
    self.trackedItem = itemLink
end

-- Award item to player, based on args and self.trackedItem
function LA:GiveFromConsole(itemIdOrLinkOrPlayerName)
    self:Print("GiveFromConsole", itemIdOrLinkOrPlayerName)

    local split = strsplit(" ", itemIdOrLinkOrPlayerName)
    if #split == 1 then
        self:Print("1 arg")
        -- Make sure this is not a itemId
        local id = GetItemInfoInstant(itemIdOrLinkOrPlayerName)
        if id then
            self:Print("Cannot use give without playername")
            return
        end

        local playerName = self:GuessPlayerName(split[1])
        if not playerName then
            self:Print("No player found")
            return
        end

        if not self.trackedItem then
            self:Print("No currently tracked item")
            return
        end

        self:Award(self.trackedItem, playerName)
    end
end

-- Guess proper playername from current raid roster based on slug
-- may need to keep a daily cache of known playernames
function LA:GuessPlayerName(playerName)
    self:Print("GuessPlayerName", playerName)
    if not playerName then
        return
    end

    local playerSlug = self:ToSlug(playerName)

    local roster = {}
    if IsInRaid() then
        for i = 1, MAX_RAID_MEMBERS do
            local name = GetRaidRosterInfo(i)
            if name ~= nil then
                tinsert(roster, {name = name, slug = self:ToSlug(name), stripped = self:StripAccents(name)})
            end
        end
    elseif IsInGroup() then
        local group = GetHomePartyInfo()
        for _, name in ipairs(group) do
            if name ~= nil then
                tinsert(roster, {name = name, slug = self:ToSlug(name), stripped = self:StripAccents(name)})
            end
        end
    else
        self:Print("Not in group or raid")
        -- return
    end

    -- self:PrintTable(roster)

    -- Perfect match
    for _, unit in ipairs(roster) do
        if unit["slug"] == playerSlug then
            self:Print("Perfect match", unit["name"])
            return unit["name"]
        end
    end

    -- Contains
    for _, unit in ipairs(roster) do
        if strfind(unit["slug"], playerSlug) then
            self:Print("Match contains", unit["name"])
            return unit["name"]
        end
    end

    -- Strip accents
    for _, unit in ipairs(roster) do
        if strfind(unit["stripped"], playerSlug) then
            self:Print("Match stripped", unit["name"])
            return unit["name"]
        end
    end

    self:Print("Failed to match", playerName)
    return nil
end

-- Send to raid/group
function LA:Announce(str)
    if IsInRaid() then
        if self.db.profile.announceTo == "RAID_WARNING" then
            if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
                -- SendChatMessage(str, self.db.profile.announceTo)
                self:Print("Send to", self.db.profile.announceTo, str)
            else
                self:Print("Using raid channel as you are not raid leader / assistant")
                -- SendChatMessage(str, "RAID")
                self:Print("Send to", "RAID", str)
            end
        elseif self.db.profile.announceTo == "RAID" then
            -- SendChatMessage(str, self.db.profile.announceTo)
            self:Print("Send to", self.db.profile.announceTo, str)
        end
    elseif IsInGroup() then
        if self.db.profile.announceTo == "RAID_WARNING" then
            -- SendChatMessage(str, self.db.profile.announceTo)
            self:Print("Send to", self.db.profile.announceTo, str)
        elseif self.db.profile.announceTo == "RAID" then
            -- SendChatMessage(str, "PARTY")
            self:Print("Send to", "PARTY", str)
        end
    else
        self:Print("Not in raid/group, cannot announce", str)
    end
end

-- Store item distribution in database
function LA:StoreLootAwarded(itemId, playerName)
    local loot = {id = itemId, name = playerName, t = time()}
    tinsert(self.db.factionrealm.history[self.currentGuild], loot)
    self:LiveSync(loot)
end

-- Store current guild name & player rank
function LA:FetchCurrentGuild()
    if not IsInGuild() then
        return
    end

    local guildName, guildRankName = GetGuildInfo("player")
    if not guildName then
        return
    end

    self.currentGuild = guildName
    self.currentGuildRank = guildRankName
end

-- Send live distribution addition / removal
function LA:LiveSync(loot)
    -- Dedup
end

-- Trigger database sync with other guild members
function LA:SyncDB()
end

-- Receive DB contents
function LA:ReceiveSyncDB(str)
end

-- Receive live distribution addition / removal
function LA:ReceiveLiveSync(str)
end

-- Reset entire database
function LA:ResetDatabase()
    self.db:ResetDB()
    self:Print(L["Database reset"])
end

-- Draw minimap icons and bind buttons
function LA:DrawMinimapIcon()
	libDBIcon:Register(addonName, LibStub("LibDataBroker-1.1"):NewDataObject(addonName,
	{
		type = "data source",
		text = addonName,
        icon = "interface/icons/inv_misc_key_02",
		OnClick = function(self, button)
			if (button == "RightButton") then
                InterfaceOptionsFrame_OpenToCategory(addonName)
                InterfaceOptionsFrame_OpenToCategory(addonName)
            else
                LA:ToggleGUI()
            end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(string.format("%s |cff777777v%s|r", addonTitle, addonVersion))
			tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Left Click"], L["to open the main window"]))
			tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Right Click"], L["to open options"]))
			tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Drag"], L["to move this button"]))
		end
    }), self.db.profile.minimapButton)
end

function LA:ToggleMinimapButton()
    self.db.profile.minimapButton.hide = not self.db.profile.minimapButton.hide
    if self.db.profile.minimapButton.hide then
        libDBIcon:Hide(addonName)
    else
        libDBIcon:Show(addonName)
    end
end

function LA:GenerateRows(sortColumn)
    -- self:Print("Rebuilding data table")
    local tbl = {}

    if not self.db.factionrealm.history[self.currentGuild] then
        return tbl
    end

    for _, row in ipairs(self.db.factionrealm.history[self.currentGuild]) do
        table.insert(tbl, {})
    end

    if sortColumn then
        if self.sortColumn == sortColumn then
            self.sortOrder = not self.sortOrder
        else
            self.sortColumn = sortColumn
            self.sortOrder = true
        end
    end

    table.sort(tbl, function(a, b)
        if self.sortOrder then
            return a[self.sortColumn] > b[self.sortColumn]
        else
            return b[self.sortColumn] > a[self.sortColumn]
        end
    end)

    return tbl
end

function LA:OptimizeDatabase()
    self:CleanupDatabase()
end

function LA:CleanupDatabase()
    if self.db.profile.maxHistory == 0 then
        return
    end

    local count = #self.db.factionrealm.history[self.currentGuild]
    if count > self.db.profile.maxHistory then
        removemulti(self.db.factionrealm.history[self.currentGuild], self.db.profile.maxHistory, self.db.factionrealm.history[self.currentGuild] - self.db.profile.maxHistory)
    end
end