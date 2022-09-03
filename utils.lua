local addonName = "LootArchive"
local LA = LibStub("AceAddon-3.0"):GetAddon(addonName)

function LA:ToSlug(name)
    return strlower(name)
end

-- function LA:SlugToName(slug)
--     return strupper(strsub(slug, 1, 1)) .. strlower(strsub(slug, 2))
-- end

function LA:StripAccents(name)
    local slug = self:ToSlug(name)

    local tbl = {
        ["ß"] = "s",
        ["à"] = "a",
        ["á"] = "a",
        ["â"] = "a",
        ["ã"] = "a",
        ["ä"] = "a",
        ["å"] = "a",
        ["æ"] = "ae",
        ["ç"] = "c",
        ["è"] = "e",
        ["é"] = "e",
        ["ê"] = "e",
        ["ë"] = "e",
        ["ì"] = "i",
        ["í"] = "i",
        ["î"] = "i",
        ["ï"] = "i",
        ["ð"] = "o",
        ["ñ"] = "n",
        ["ò"] = "o",
        ["ó"] = "o",
        ["ô"] = "o",
        ["õ"] = "o",
        ["ö"] = "o",
        ["ø"] = "o",
        ["ù"] = "u",
        ["ú"] = "u",
        ["û"] = "u",
        ["ü"] = "u",
        ["ý"] = "y",
        ["þ"] = "p",
        ["ÿ"] = "y"
    }

    return gsub(slug, "[%z\1-\127\194-\244][\128-\191]*", tbl)
end

function LA:PrintTable(table)
    for key, value in pairs(table) do
        if type(value) == "table" then
            self:Print(key, "=")
            self:PrintTable(value)
        else
            self:Print(key, "=", value)
        end
    end
end

function LA:PrintArray(arr)
    for i, value in ipairs(arr) do
        self:Print(i, "=", value)
    end
end

function LA:StrRemove(s, el)
    local escapedEl = gsub(gsub(gsub(el, "%[", "%%[", 1), "%]", "%%]", 1), "%-", "%%-")
    local removedString = gsub(s, escapedEl, "", 1)
    return strtrim(strtrim(removedString))
end
