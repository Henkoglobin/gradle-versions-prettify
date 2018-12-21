#!/usr/bin/env lua

local json = require("json.json")

local semVer, formatList, generatePraise, isShortHash
local function main(fileName)
    local file = io.open(fileName)
    local data = json.decode(file:read("*a"))
    file:close()

    local majorUpgrades, minorUpgrades, patchUpgrades = {}, {}, {}
    local longestNameLength = 0

    for _, dependency in pairs(data.outdated.dependencies) do
        local nameLength = #dependency.group + #dependency.name + 1
        if nameLength > longestNameLength then
            longestNameLength = nameLength
        end

        local currMajor, currMinor, currPatch = semVer(dependency.version)
        local latestMajor, latestMinor, latestPatch = semVer(dependency.available.release)

        local targetList = (function()
            if latestMajor > currMajor then
                return majorUpgrades
            elseif latestMinor > currMinor then
                return minorUpgrades
            elseif latestPatch > currPatch then
                return patchUpgrades
            end
        end)()

        table.insert(targetList, dependency)
    end

    if next(majorUpgrades) then
        print("Major (Possibly Breaking) Updates")
        print("=================================")
        print()
        print(formatList(majorUpgrades, longestNameLength))
        print()
        print()
    end

    if next(minorUpgrades) then
        print("Minor Updates")
        print("=================================")
        print()
        print(formatList(minorUpgrades, longestNameLength))
        print()
        print()
    end

    if next(patchUpgrades) then
        print("Patch (Bugfix) Updates")
        print("=================================")
        print()
        print(formatList(patchUpgrades, longestNameLength))
        print()
        print()
    end

    if next(data.unresolved.dependencies) then
        print("Unresolved Dependencies")
        print("=================================")
        print()

        for _, dependency in pairs(data.unresolved.dependencies) do
            print(("Could not resolve %s:%s:%s"):format(dependency.group, dependency.name, dependency.version))
            if isShortHash(dependency.version) then
                print("This version seems to be a git commit hash.")
                print("Consider using a release version of this dependency.")
                print()
            end
        end

        print()
    end

    local gradleCurrMajor, gradleCurrMinor, gradleCurrPatch = semVer(data.gradle.running.version)
    local gradleLatestMajor, gradleLatestMinor, gradleLatestPatch = semVer(data.gradle.current.version)

    local praise = generatePraise(data.current.count, data.count)
    print(("%d/%d dependencies already up-to-date. %s"):format(data.current.count, data.count, praise))

    if gradleLatestMajor > gradleCurrMajor or gradleLatestMinor > gradleCurrMinor or gradleLatestPatch > gradleCurrPatch then
        print()
        print("Gradle Update Available")
        print("=================================")
        print()
        print(("Gradle can be updated from %s to %s"):format(data.gradle.running.version, data.gradle.current.version))
        print()
    end
end

semVer = function(versionString)
    local nums = {}

    versionString:gsub("%d+", function(num) table.insert(nums, num) end)

    return tonumber(nums[1]) or 0, tonumber(nums[2]) or 0, tonumber(nums[3]) or 0
end

local padRight
formatList = function(dependencies, longestNameLength)
    local lines = {}
    for _, dependency in pairs(dependencies) do
        local artifactName = ("%s:%s"):format(dependency.group, dependency.name)
        table.insert(lines, ("%s\t%s => %s"):format(padRight(artifactName, longestNameLength), dependency.version, dependency.available.release))
    end

    return table.concat(lines, "\n")
end

padRight = function(str, len)
    local diff = len - #str
    return str .. string.rep(" ", diff)
end

generatePraise = function(current, total)
    local percentageCurrent = current / total

    if percentageCurrent > 0.95 then
        return "You're perfectly current!"
    elseif percentageCurrent > 0.9 then
        return "Good job!"
    elseif percentageCurrent > 0.8 then
        return "Fair enough, but please update soon!"
    elseif percentageCurrent > 0.5 then
        return "You may have forgotten to update in the last time..."
    else
        return "Please take the time to update your dependencies right now."
    end
end

isShortHash = function(versionString)
    return not not versionString:find("^%x+$")
end

main(...)
