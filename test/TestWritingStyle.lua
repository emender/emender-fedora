-- TestWritingStyle.lua - Test which check violations in writing style.
-- Copyright (C) 2015 Pavel Vomacka
--
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

TestWritingStyle = {
    -- required field
    metadata = {
        description = "Checks writing style.",
        authors = "Pavel Vomacka",
        emails = "pvomacka@redhat.com",
        changed = "2016-04-01",
        tags = {"DocBook", "WritingStyle"},
    },
    xmlObj = nil,
    pubObj = nil,
    docObj = nil,
    getReadableText = nil,
    dbFile = "writing_style.db"
}


--
--- Fetch incorrect words from database.
--
--
function TestWritingStyle.getIncorrectWords()
    if not path.file_exists(TestWritingStyle.dbFile) then
        warn("Database file does not exist.")
        return nil
    end

    -- Compose command which gets data from database.
    local command = "sqlite3 \"" .. TestWritingStyle.dbFile .. "\" 'SELECT name FROM item WHERE type=\"word\" AND use_it=0;'"

    -- Execute command, capture its output and output it.
    local dbOutput = execCaptureOutputAsTable(command)

    -- In case that there is no information found in database then the sql library returns nil.
    -- This nil value is tranformed to the empty table and returned. It helps when we want to
    -- recognize wheteher database file does not exist, or there is no information and therefor
    -- prints only one warning.
    if not dbOutput then dbOutput = {} end
    return dbOutput
end


--
--- Fetch correct words from database.
--
--
function TestWritingStyle.getCorrectWords()
    if not path.file_exists(TestWritingStyle.dbFile) then
        warn("Database file '" .. TestWritingStyle.dbFile .. "' does not exist.")
        return nil
    end

    local sqlObj = sql.create(TestWritingStyle.dbFile)

    -- Compose command which gets data from database.
    local command = "SELECT name FROM item WHERE type='word' AND use_it=1"

    -- Execute command, capture its output and output it.
    local dbOutput = sqlObj:executeQueryGetAll(command)

    -- In case that there is no information found in database then the sql library returns nil.
    -- This nil value is tranformed to the empty table and returned. It helps when we want to
    -- recognize wheteher database file does not exist, or there is no information and therefor
    -- print only one warning.
    if not dbOutput then dbOutput = {} end
    return dbOutput
end


--
--- Get all files which are included in current book.
--
--  @return table with one item form each file.
function TestWritingStyle.getFileList(fileN, language)
    -- Handle a situaion when xml file doesn't exist.
    if not path.file_exists(fileN) then
        return nil
    end

    -- create xml object for document main file and turn off the xincludes.
    local xmlObj = xml.create(fileN, 0)
    local wholeFileList = {}
    table.insert(wholeFileList, fileN)

    -- Get content of href attribute from the main file.
    local fileList = xmlObj:parseXml("//newnamespace:include/@href", "http://www.w3.org/2001/XInclude")

    -- If there is no other includes in the current file then return list with only current file.
    if not fileList then
        return wholeFileList
    end

    -- Append en-US directory for each file name and store it back to the table.
    for i, fileName in ipairs(fileList) do
        --print("expand", fileName)
        if not fileName:match("^" .. language) then
            fileList[i] = language .. "/" .. fileName
        end

        local nextFiles = TestWritingStyle.getFileList(fileList[i], language)

        if nextFiles then
            wholeFileList = table.appendTables(wholeFileList, nextFiles)
        end
    end

    -- Return the result table.
    return wholeFileList
end


--
--- This function is run as first.
--
function TestWritingStyle.setUp()
    dofile(getScriptDirectory() .. "lib/xml.lua")
    dofile(getScriptDirectory() .. "lib/publican.lua")
    dofile(getScriptDirectory() .. "lib/docbook.lua")
    dofile(getScriptDirectory() .. "lib/sql.lua")

    -- Get database with information about words.
    local workingDir = getWorkingDirectory()
    TestWritingStyle.dbFile = path.compose(workingDir, TestWritingStyle.dbFile)

    -- Create publican object.
    TestWritingStyle.pubObj = publican.create("publican.cfg")

    -- Create xml object.
    TestWritingStyle.xmlObj = xml.create(TestWritingStyle.pubObj:findMainFile())

    -- Create docbook object.
    TestWritingStyle.docObj = docbook.create(TestWritingStyle.pubObj:findMainFile())

    -- Get readable text.
    TestWritingStyle.readableText = TestWritingStyle.docObj:getReadableText()
    --print("ReadableText:", TestWritingStyle.readableText)

    -- Get language code from this book.
    local language = TestWritingStyle.pubObj:getOption("xml_lang")

    -- Default language is en-US:
    if not language then
      language = "en-US"
    end

    -- Get list of xml files.
    TestWritingStyle.fileList = TestWritingStyle.getFileList(TestWritingStyle.pubObj:findMainFile(), language)
end

--
--- Function that checks whether incorrect words are not used.
--
function TestWritingStyle.testUsingCorrectWords()
    -- Read the incorrect words from database
    local incorrectWords = TestWritingStyle.getIncorrectWords()

    if not incorrectWords then
        return
    elseif table.isEmpty(incorrectWords) then
        pass("No incorrect words.")
    end

    -- Convert list of words from database
    local incorrectWords = table.setValueToKey(incorrectWords)

    -- Go through all words in readable text and try to find them
    local concatenatedText = table.concat(TestWritingStyle.readableText)

    -- Variable which determines whether there is at least one incorrect word
    local failed = false

    -- Go through all incorrect words
    for word, _ in pairs(incorrectWords) do
        -- Set counter of words.
        local counter = 0

        -- Count occurences of this word.
        for x in concatenatedText:gmatch(word) do
            counter = counter + 1
            failed = true
        end

        -- If there is at least one occurence of incorrect word then print error.
        if counter > 0 then
            fail("Word: '**" .. word .. "**' is used **" .. counter .. "** time(s).")
        end
    end

    -- If there is no word in text from incorrect words then print pass message.
    if not failed then
        pass("Incorrect words are not used.")
    end
end


--
--- Function that check all words from readable part of book against aspell.
--
function TestWritingStyle.testSpellChecking()
    -- Fetch words from database which we can use.
    local allowedWords = TestWritingStyle.getCorrectWords()
    allowedWords = table.setValueToKey(allowedWords)

    -- Go through all files and check every file.
    for _, filePath in ipairs(TestWritingStyle.fileList) do
        print()
        pass("Checking **" .. filePath .. "**.")
        local fileObj = docbook.create(filePath)

        -- Get readable part of the current file.
        local readableParts = fileObj:getReadableText(0)

        -- Only if readable parts are not nil.
        if readableParts then
            local helpString = table.concat(readableParts, " ")
            readableParts = helpString
            incorrectWords = {}

            -- Go through readable parts word by word.
            for word in readableParts:gmatch("[%w%p-]+") do
                word = string.trimString(word)
                local cmd = "echo \"" .. word .. "\" | aspell -H list -l en-US"

                -- In case that output of the command is not empty string,
                -- then the aspell reports the word as it is incorrect.
                if not execCaptureOutputAsString(cmd):match("^$") then
                    -- The word is incorrect.
                    if not incorrectWords[word] then
                        incorrectWords[word] = 1
                    else
                        incorrectWords[word] = incorrectWords[word] + 1
                    end

                    -- Create helpWord variable which is without "'s" at the end of the string.
                    -- So, we can check for example "API's".
                    local helpWord = word
                    if word:match("'s$") then
                        helpWord = word:gsub("'s$", "")
                    end

                    -- words are filtered using aspell, now filter words which are allowed
                    -- in our database and remove abbreviations according to acrobot database.
                    -- First our writing style database.
                    if allowedWords and allowedWords[helpWord] then
                        -- Remove words which are correct according to our WritingStyle database.
                        incorrectWords[word] = nil
                    end
                end
            end

            -- Print the result of test.
            for word, count in pairs(incorrectWords) do
                warn("The **" .. word .. "** occurred **" .. count .. "** time(s).")
            end
        end
    end
end
