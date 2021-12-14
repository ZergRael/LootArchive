local addonName = "LootArchive"
local _, addonTitle, addonNotes = GetAddOnInfo(addonName)
local LA = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function LA:RegisterOptionsTable()
    AceConfig:RegisterOptionsTable(addonName, {
        name = addonName,
        descStyle = "inline",
        handler = LA,
        type = "group",
        args = {
            Toggle = {
                order = 1,
                type = "execute",
                name = L["Toggle GUI"],
                func = function() self:ToggleGUI() end
            },
            Add = {
                order = 2,
                type = "execute",
                name = L["Add item"],
                desc = L["Add item link or id to distribute"],
                func = function(f)
                    local itemIdOrLink = strtrim(select(2, strsplit(" ", f["input"], 2)))
                    self:AddFromConsole(itemIdOrLink)
                end
            },
            Give = {
                order = 2,
                type = "execute",
                name = L["Give item"],
                desc = L["Store item link or id as awarded to a player"],
                func = function(f)
                    local itemIdOrLinkOrPlayerName = strtrim(select(2, strsplit(" ", f["input"], 2)))
                    self:GiveFromConsole(itemIdOrLinkOrPlayerName)
                end
            },
            Guess = {
                order = 4,
                type = "execute",
                name = "DEBUG: Guess name",
                func = function(f)
                    local name = select(2, strsplit(" ", f["input"], 2))
                    self:GuessPlayerName(name)
                end
            },
            General = {
                order = 10,
                type = "group",
                name = L["Options"],
                args = {
                    intro = {
                        order = 0,
                        type = "description",
                        name = addonNotes,
                    },
                    announce = {
                        order = 10,
                        type = "group",
                        name = L["Announce settings"],
                        inline = true,
                        args = {
                            announceTo = {
                                order = 10,
                                type = "select",
                                name = L["Announce to"],
                                desc = L["Channel used to send distribution announces"],
                                values = {RAID_WARNING = L["Raid warning"], RAID = L["Raid"]},
                                get = function() return self.db.profile.announceTo end,
                                set = function(_, val) self.db.profile.announceTo = val end,
                            },
                            callLootStr = {
                                order = 20,
                                type = "input",
                                name = L["Raid loot announce pattern"],
                                get = function() return self.db.profile.callLootStr end,
                                set = function(_, val) self.db.profile.callLootStr = val end,
                                validate = function(_, val)
                                    local _, count = gsub(val, "%%s", "")
                                    if count == 1 then
                                        return true
                                    else
                                        return "Invalid : requires a %s placeholder for item link"
                                    end
                                end,
                            },
                            awardStr = {
                                order = 30,
                                type = "input",
                                name = L["Raid loot distribution pattern"],
                                get = function() return self.db.profile.awardStr end,
                                set = function(_, val) self.db.profile.awardStr = val end,
                                validate = function(_, val)
                                    local _, count = gsub(val, "%%s", "")
                                    if count == 2 then
                                        return true
                                    else
                                        return "Invalid : requires 2 %s placeholders for item link and winning playername"
                                    end
                                end,
                            },
                        },
                    },
                    db = {
                        order = 20,
                        type = "group",
                        name = L["Database Settings"],
                        inline = true,
                        args = {
                            maxHistory = {
                                order = 11,
                                type = "range",
                                name = L["Maximum records in history"],
                                desc = L["Awarded loots history can use a lot of memory (0 means unlimited)"],
                                min = 0,
                                max = 1000,
                                step = 10,
                                get = function() return self.db.profile.maxHistory end,
                                set = function(_, val) self.db.profile.maxHistory = val end,
                            },
                            purge = {
                                order = 19,
                                type = "execute",
                                name = L["Purge database"],
                                desc = L["Delete all collected data"],
                                confirm = true,
                                func = function() self:ResetDatabase() end
                            },
                        },
                    },
                    minimap = {
                        order = 30,
                        type = "group",
                        name = L["Minimap Button Settings"],
                        inline = true,
                        args = {
                            minimapButton = {
                                order = 21,
                                type = "toggle",
                                name = L["Show minimap button"],
                                get = function()
                                    return not self.db.profile.minimapButton.hide
                                end,
                                set = 'ToggleMinimapButton',
                            },
                        },
                    },
                }
            },
            Profiles = AceDBOptions:GetOptionsTable(LA.db),
        }
    }, {"LA"})
    AceConfigDialog:AddToBlizOptions(addonName, nil, nil, "General")

    AceConfigDialog:AddToBlizOptions(addonName, "Profiles", addonName, "Profiles")
end
