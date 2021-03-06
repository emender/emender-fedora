-- TestCommandFlags.lua - a test to verify that all command flags exist
-- Copyright (C) 2015 Pavel Vomacka

-- This program is free software:  you can redistribute it and/or modify it
-- under the terms of  the  GNU General Public License  as published by the
-- Free Software Foundation, version 3 of the License.
--
-- This program  is  distributed  in the hope  that it will be useful,  but
-- WITHOUT  ANY WARRANTY;  without  even the implied warranty of MERCHANTA-
-- BILITY or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
-- License for more details.
--
-- You should have received a copy of the GNU General Public License  along
-- with this program. If not, see <http://www.gnu.org/licenses/>.

TestCommandFlags = {
    metadata = {
        description = "Verify that all commands flags exist.",
        authors = "Pavel Vomacka",
        emails = "pvomacka@redhat.com",
        changed = "2016-12-25",
        tags = {"DocBook", "Release"}
    },
    requires = {"xmllint", "xmlstarlet", "sqlite3"},
    publObj = nil,
    xmlObj = nil,
    sqlObj = nil,
    ------------------------------ CONFIGURATION ------------------------------
    -- This test consumes database generated by tool from:
    -- https://github.com/pvomacka/manpageParser
    -- Default OS:
    product = "Fedora",
    -- Default version:
    version = "25",
    -- Default database file - could be changed using --XsqlFile=path/to/file
    sqlFile = "/tmp/switchTest/switch.sqlite3",
    ----------------------------------- END -----------------------------------
    commands = nil,
    manpagesContent = nil,
    dictionary = {["git add"] = "git-add", ["git am"] = "git-am",
                  ["git annotate"] = "git-annotate", ["git apply"] = "git-apply",
                  ["git archive"] = "git-archive", ["git bisect"] = "git-bisect",
                  ["git blame"] = "git-blame", ["git branch"] = "git-branch",
                  ["git bundle"] = "git-bundle", ["git cat-file"] = "git-cat-file",
                  ["git check-attr"] = "git-check-attr",
                  ["git check-ignore"] = "git-check-ignore",
                  ["git check-ref-format"] = "git-check-ref-format",
                  ["git checkout-index"] = "git-checkout-index",
                  ["git commit"] = "git-commit",
                  ["git push"] = "git-push", ["git diff"] = "git-diff"}
}


--
--- Prints information about current test configuration.
--
function TestCommandFlags.printInformation()
    local content = "Current test configuration: \n\tProduct: " .. TestCommandFlags.product .. "\n\tVersion: "
                   .. TestCommandFlags.version

    -- Print information about test configuration.
    warn(content)
end

--
--- Function which convert list from {[1]="a", [2]="b", etc.}
--  to {[a]=true. [b]=true, etc.}. Just because of speed
--  of finding items.
-- @param list List which should be converted.
-- @return Returns converted list.
function TestCommandFlags.convertList(list)
    local set = {}
    -- In case that the command doesnt have flags return empty table
    if not list then return set end

    for _, l in ipairs(list) do
        set[l] = true
    end

    return set
end


--
--- Fetch system ID from database_file
--  Concatenated os name and version is taken as os name
--
function TestCommandFlags.getSystemIdFromDB()
    local product = TestCommandFlags.product .. TestCommandFlags.version
    local query = "SELECT id FROM system WHERE name='" .. product .. "';"
    local sysId = TestCommandFlags.sqlObj:executeQueryGetFirst(query)

    return sysId
end


--
--- Fetch all commands for current OS from database
--
-- @param sysId system id
function TestCommandFlags.getCommandsFromDB(sysId)
    local query = "SELECT command, id FROM command WHERE system_id='" .. sysId .. "';"
    return TestCommandFlags.sqlObj:executeQueryGetAll(query)
end


--
--- Fetch flags for all commands in cmds list
--
-- @param cmds commands list
function TestCommandFlags.getFlagsFromDB(cmds)
    local commandsFlags = {}

    for _,cmd in ipairs(cmds) do
        -- Parse id and command name
        local getOutput = cmd:gmatch("(.*)|(.*)")
        name, id = getOutput()

        local query = "SELECT switch FROM switch WHERE command_id='" .. id .."';"
        local flags = TestCommandFlags.sqlObj:executeQueryGetAll(query)

        -- put there true for commands withou flags
        if flags then
            commandsFlags[name] = flags
        else
            commandsFlags[name] = true
        end
    end

    return commandsFlags
end


--
--- Handles fetching data from database
--
function TestCommandFlags.fetchExistingData()
    -- Get os version
    local sysId = TestCommandFlags.getSystemIdFromDB()

    if sysId == nil then
        local product = TestCommandFlags.product .. TestCommandFlags.version
        fail("The '" .. product .. "' system has not been found in the database.")
        return nil
    end

    -- Get commands according to sysId
    local commands = TestCommandFlags.getCommandsFromDB(sysId)

    -- Get appropriate flags and connect them with command
    return TestCommandFlags.getFlagsFromDB(commands);
end


--
--- Chooses only flags which contains only one character
--
-- @param availableFlags list of flags
function TestCommandFlags.getOneLetterFlags(availableFlags)
    local oneLetters = {}

    for flag, _ in pairs(availableFlags) do
        if flag:match("^%-[a-zA-Z0-9#?]$") then
            local f = flag:gsub("^%-", "") -- remove dash from the beginning
            oneLetters[f] = true
        end
    end

    return oneLetters

end


--
--- Check whether flag passed as first argument is composed from flags in
--  second parameter which is list of one letter flags.
--
-- @param flag name of flag which should be checked
-- @param availableFlags available one letter flags
function TestCommandFlags.checkComposedFlag(flag, availableFlags)
    -- composed flags has to begin with one dash.
    if not flag:match("^%-[^%-]") then
        return false
    end

    -- Get all letters which are stored in one letter flags without dash so:
    -- from '-l' we'll get just 'l'
    local oneLetters = TestCommandFlags.getOneLetterFlags(availableFlags)

    if #flag < 2 then return false end

    -- Go through found flag letter by letter and try to find those letters in
    -- list of one letter flags
    for i = 2, #flag do
        local char = flag:sub(i,i)
        if not oneLetters[char] then return false end
        -- do something with c
    end

    return true

end


--
--- Fetch all flags which starts with dash from current command. Save results
--  to the table.
--
--  @param command which will be parsed
--  @return table with all flags from current command
function TestCommandFlags.fetchFlags(command)
    local flags = {}
    local composedCommand = ""
    local flagFound = false
    local separatedCommand = false

    -- Go through all words.
    for word in command:gmatch("[%w%p]+") do
        if word:match("^%-.*") then
            -- Take only part before first equals character or space character
            word = word:match("^(%-[^\"'{}%(%)%[%]=%s]*).*")
            flagFound = true
            flags[word] = true
        elseif not flagFound and not separatedCommand and word:match("^%w") then
            composedCommand = composedCommand .. " " .. word
            composedCommand = string.ltrim(composedCommand)

            -- If words concatented in composedCommand string then exist in dictionary,
            -- then use the command from dictionary.
            if TestCommandFlags.dictionary[composedCommand] then
                separatedCommand = true
                composedCommand = TestCommandFlags.dictionary[composedCommand]
            end
        end
    end

    -- Set composed from empty string to nil.
    if not separatedCommand then composedCommand = nil end

    -- If there is at least one flag then return it, in case that there is no flag then return nil.
    -- In both cases return also composedCommand.
    if flagFound then
        return {flags, composedCommand}
    else
        return {nil, composedCommand}
    end
end


--
--- Parse content of all command tags.
--
--    @param command_list table of commands fetched from command tag.
--    @return list with commands and their flags. {[command1]={f1,f2,f3}, [command2]={f4,f3,f}, ..}
function TestCommandFlags.parseCommands(commandsList)
    local resultList = {}

    for _,command in ipairs(commandsList) do
        if command:match("^%w") then
            -- Command has pipe in it.
            if command:match("%s|%s") then
                splitCommands = command:gmatch("(.+)%s|%s(.+)")
                local first, second = splitCommands()
                command = second
                commandsList[#commandsList+1] = first
            end

            -- Remove # or ? character from the beginning of string.
            command = command:gsub("^[#%?]%s?", "")
            resultList[command] = TestCommandFlags.fetchFlags(command)
        end
    end

    return resultList
end


--
--- Concatenates two tables into one.
--
--  @param t1 table which will be extended
--  @param t2 table which will be append to the table1
--  @return table with values from both tables
function TestCommandFlags.tableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end

    return t1
end


--
--- Function which runs the first.
--
function TestCommandFlags.setUp()
    dofile(getScriptDirectory() .. "lib/xml.lua")
    dofile(getScriptDirectory() .. "lib/publican.lua")
    dofile(getScriptDirectory() .. "lib/docbook.lua")
    dofile(getScriptDirectory() .. "lib/sql.lua")

    TestCommandFlags.printInformation()

    -- Create publican and xml objects.
    TestCommandFlags.publObj = publican.create("publican.cfg")
    TestCommandFlags.xmlObj = xml.create(TestCommandFlags.publObj:findMainFile())
    TestCommandFlags.sqlObj = sql.create(TestCommandFlags.sqlFile)

    local commandTags = TestCommandFlags.xmlObj:getElements("command")

    if not commandTags then
        warn("No command found...")
    else
        -- Fetch and parse all commands
        TestCommandFlags.commands = TestCommandFlags.parseCommands(commandTags)

        -- Fetch data from database with current system version.
        TestCommandFlags.commandsFlags = TestCommandFlags.fetchExistingData()
    end
end


--
--- Main test function.
--
--
function TestCommandFlags.testFlags()
    if not TestCommandFlags.commands then
        warn("No command found...")
    else
        for whole_command, flags_table in pairs(TestCommandFlags.commands) do

            local getCommandName = whole_command:gmatch("([^%s]*)")
            local command = getCommandName()

            if flags_table[1] then
                local availableCommandFlags = TestCommandFlags.commandsFlags[command]
                if type(availableCommandFlags) == "nil" then
                    warn ("Command **" .. command .. "** does not exists in DB. From command: **" .. whole_command .. "**")
                elseif type(availableCommandFlags) == "boolean" then
                    warn("Command **" .. command .. "** does not have any flags in DB. From command: **" .. whole_command .. "**")
                else
                    local availableCommandFlags = TestCommandFlags.convertList(availableCommandFlags)
                    for flag, _ in pairs(flags_table[1]) do
                        if availableCommandFlags[flag] then
                            pass("Flag **" .. flag .. "** from command **" .. whole_command .. "** exists.")
                        else
                            -- Check whether flag is not compossed from more one letter
                            -- flags
                            local composedFlag = TestCommandFlags.checkComposedFlag(flag, availableCommandFlags)
                            if composedFlag then
                                pass("Flag **" .. flag .. "** from command **" .. whole_command .. "** exists. NOTE: composed flag.")
                            else
                                fail("Flag **" .. flag .. "** from command **" .. whole_command .. "** does not exists.")
                            end
                        end
                    end
                end
            end
        end
    end
end


--
--- Test whether commands used in document exist.
--
--
function TestCommandFlags.testCommands()
    if not TestCommandFlags.commands then
        warn("No command found...")
    else
        local alreadyTested = {}
        for wholeCommand, _ in pairs(TestCommandFlags.commands) do
            local getCommandName = wholeCommand:gmatch("([^%s]*)")
            local command = getCommandName()
            if not alreadyTested[command] and command:match("^[_%-%w]*$") then
                if TestCommandFlags.commandsFlags[command] then
                    pass("Command **" .. command .. "** exists.")
                else
                    fail("Command **" .. command .. "** does not exists.")
                end

                -- Add command to the table where are already tested commands.
                alreadyTested[command] = true
            end
        end
    end
end
