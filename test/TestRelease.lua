-- TestRelease.lua - Test if a book is ready for a GA and beta release.
-- Copyright (C) 2014-2015 Barbora Ancincova

-- This file is part of Emender.

-- Emender is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; version 3 of the License.
--
-- Emender is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Emender.  If not, see <http://www.gnu.org/licenses/>.


-- NOTE: this test must be run in the directory with the publican.cfg file. The release variable is equal to current release number (for example 21) and must be specified by the --X option when running emender - emend --Xrelease=21.

TestRelease = {
    metadata = {
        description = "Test if a book is ready for a release.",
        authors = "Barbora Ancincova",
        emails = "bancinco@redhat.com",
        changed = "2015-01-14",
        tags = {"Sanity", "XML"}
    },
    requires = {"git", "grep", "xmlstarlet","xmllint"},
    debug = "0",
    language = "en-US",
    brand = "fedora"
}

function TestRelease.setUp()
    TestRelease.verifyPath()
    TestRelease.rootfile = TestRelease.findStartFile()
    if not TestRelease.verifyUsedFiles() then return end
    --TestRelease.testBranch()
end

-- Print debugging information to standard error output
function TestRelease.printDebug(message)
    if TestRelease.debug ~= "0" then
    io.stderr:write("DEBUG: '" .. message .. "'\n\n")
    end
end

--Verify that the en-US/Author_Group.xml, en-US/Book_Info.xml files exist.
function TestRelease.verifyUsedFiles()
    if not TestRelease.checkFile("en-US/Author_Group.xml", "er") then
        fail("The Author_Group.xml file does not exist.")
        return false
      end
    if not TestRelease.checkFile("en-US/Book_Info.xml", "er") then
        fail("The Book_Info.xml file does not exist.")
        return false
      end
    if not TestRelease.checkFile("en-US/Revision_History.xml", "er") then
        fail("The Revision_History.xml file does not exist.")
        return false
      end
    return true
end

-- Test if you are in the correct branch for example 7.0_GA, 7.1_Beta.
-- TODO - do we need this in Fedora (should we establish the same workflow?)
--function TestRelease.testBranch()
--    local find_gitcongif = "test -f .git/config;echo $?"
--        local output = TestRelease.readOutput(find_gitcongif)
--    if output == "0" then
--        local git = "git rev-parse --abbrev-ref HEAD"
--        local output = TestRelease.readOutput(git)
--        is_equal(output, TestRelease.release, "The git branch is correct: Got: " .. "\"" .. output .. "\"")
--    else warn("Could not verify the correct git branch. Either the test is ran in a non-git repository or in other branch then Beta or GA.")
--    end
--end

--- Find the name of the first file of a book.

-- @return Returns path of a file where the book starts.
function TestRelease.findStartFile()
    -- Checks if publican.cfg exists.
    -- If it doesn't then ends because it isn't in a DocBook format.
    if not TestRelease.checkFile(TestRelease.addPathPart(TestRelease.path, "publican.cfg"), "e") then
        fail("The book is not in the DocBook format.")
        return nil
    end
  
    -- Lists the files in language directory.
    local command = "ls " .. TestRelease.addPathPart(TestRelease.path, TestRelease.language .. "/*.ent")
  
    -- Execute the command and capture its output:
    local list_of_files = assert(io.popen(command))
  
    -- Get path to the file. Adds .xml suffix instead of .ent.
    local name = string.gsub(list_of_files:read(), "%.ent$", ".xml", 1)
  
    -- Close the file handler.
    list_of_files:close()
  
    -- Return the string with file path.
    return name
end

--Check path to publican.cfg & compose it
--function TestRelease.getPath(file)
--    local path = TestRelease.addPathPart(TestRelease.path, file)
--    if not TestRelease.checkFile(path, "ew") then
--            fail("The" .. file .. "file does not exist.")
--            return nil
--    end
--    return path
--end

-- Function which checks if path is set or not.
function TestRelease.verifyPath()
    if TestRelease.path then
        if not TestRelease.checkFile(TestRelease.path, "ed") then
            fail("Book directory doesn't exist.")
        end
    else
        -- Set empty string as a path.
        TestRelease.path = ""
    end
end

--- Function which composes a command and runs it. This command
--  will check whether some file or directory exists or whether it is
--  readable or writeable.
--
-- @param file_path Path to the file which should be checked.
-- @param test_type Type of test. Possibilities:
--                                    "e" - exists
--                                    "r" - is readable
--                                    "w" - is writeable
--                                    "d" - is directory
--                                    "f" - is file
--                  It's possible to combine these types. e.c. "wre"
-- @return True when all conditions are true. Otherwise, false.
function TestRelease.checkFile(file_path, test_type)
    -- Table of correct values of test_type:
    local types = {["e"]=true, ["r"]=true, ["w"]=true, ["d"]=true, ["f"]=true}

    -- Verify that the supplied file name is a string.
    if type(file_path) ~= "string" then
        return false
    end

    -- Get number of conditions.
    local type_lenght = string.len(test_type)

    -- Begin of command.
    local command = "[[ "

    -- Create condition for each letter in test_type.
    for i = 1, type_lenght, 1 do
        if i ~= 1 then
            command = command .. " && "
        end

        -- Get just one letter (operation) and check if it's correct.
        local operation = string.sub(test_type, i, i)
        if not types[operation] then
            fail("Bad second argument of checkFile() function.")
            return false
        end

        -- Add new condition.
        local new_part = "( -" .. operation .. " " .. file_path .. " )"
        command = command .. new_part
    end

    -- Add ending of command.
    command = command .. " ]] && echo '1' || echo '0'"

    -- Execute command and capture its output.
    file_handle = assert(io.popen(command))

    -- Check if command went correctly.
    if file_handle:read() == "0" then
        file_handle:close()
        return false
    end

    -- Close file handler.
    file_handle:close()

    return true
end


--- Function which add new part at the end of path.
--
-- @param path Path on which will be append new directory.
-- @return Returns edited path.
function TestRelease.addPathPart(path, add_string)
    -- Check if the path is not an empty string.
    if path == "" then
        return add_string
    end

    -- Check if arguments are strings.
    if type(path) ~= "string" or type(add_string) ~= "string" then
        return nil
    end

    -- Check if the path ends with '/'.
    if not string.find(path, "/$") then
        path = path .. "/"
    end

    path = path .. add_string

    -- Return the edited string.
    return path
end

-- Check the output of a command.

function TestRelease.readOutput(command)
    local fd = io.popen(command)
    local output = fd:read('*all')
    fd:close()
    output=string.trim(output)
    return output
end

-- Check that remarks are disabled.
function TestRelease.testRemarks()
    local remark_tag = "grep -q 'show_remarks:' publican.cfg;echo $?"
    local output = TestRelease.readOutput(remark_tag)
    if output== "1" then
        print("Remarks are disabled.")
    end
    if output == "0" then
        local remarks = "grep -q 'show_remarks: 0' publican.cfg;echo $?"
        local output = TestRelease.readOutput(remarks)
        TestRelease.printDebug(output)
        is_equal(output, "0", "Remarks are disabled.")
    end    
end

-- Check the correct brand
-- TODO modify the sed command to return also 'RedHat'
function TestRelease.testBrand()
    local brand = "grep brand publican.cfg | sed 's/brand:\\s*\"*\\([^\"]*\\)\"*/\\1/'"
    local output = TestRelease.readOutput(brand)
    TestRelease.printDebug(output)
    is_equal(output, TestRelease.brand, "The brand specified in the publican.cfg file is correct.  Got: " .. "\"" .. output .. "\"")
end

-- Check that there is no draft watermark
function TestRelease.testDraft()
    local draft = "xmlstarlet sel -t -v 'book/@status' "
    local command = draft .. TestRelease.rootfile .. " 2>/dev/null"
    local output = TestRelease.readOutput(command)
    TestRelease.printDebug(output)
    is_unequal(output, "draft", "The draft watermark is not present.")
end

-- Check that there is no Preface.xml and Glossary.xml included in the root file of the book.
-- TODO not sure we need this in Fedora?
function TestRelease.testPreface()
    local preface = "xmlstarlet sel -N xi='http://www.w3.org/2001/XInclude' -t -v '//xi:include/@href' " .. TestRelease.rootfile .. " 2>/dev/null | grep -q Preface.xml;echo $?"
    local output = TestRelease.readOutput(preface)
    TestRelease.printDebug(output)
    is_equal(output, "1", "The Preface.xml file is not present.")
end

function TestRelease.testGlossary()
    local glossary = "xmlstarlet sel -N xi='http://www.w3.org/2001/XInclude' -t -v '//xi:include/@href' " .. TestRelease.rootfile .. " 2>/dev/null | grep -q Glossary.xml;echo $?"
    local output = TestRelease.readOutput(glossary)
    TestRelease.printDebug(output)
    is_equal(output, "1", "The Glossary.xml file is not present.")
end

-- Check that there is not the edition tag in the Book_Info.xml file
function TestRelease.testEdition()
    local edition = "xmlstarlet sel -t -v '//edition' en-US/Book_Info.xml 2>/dev/null"
    local output = TestRelease.readOutput(edition)
    TestRelease.printDebug(output)
    is_equal(output, "", "The edition tag is not present in the Book_Info.xml file.")
end

-- Check that there is not the pubsnumber tag in the Book_Info.xml file
function TestRelease.testPubsnumber()
    local pubsnumber = "xmlstarlet sel -t -v '//pubsnumber' en-US/Book_Info.xml 2>/dev/null"
    local output = TestRelease.readOutput(pubsnumber)
    TestRelease.printDebug(output)
    is_equal(output, "", "The pubsnumber tag is not present in the Book_Info.xml file")
end

-- Check the first entry in the Revision_History.xml file.
-- TODO make it just to info - warn - How?
-- TODO how is this done with Fedora? What are the guidelines - do we add something to the Rev history? Is it necessary?
function TestRelease.testHistory()
    local history = "xmlstarlet sel -t -v '//member[1]' en-US/Revision_History.xml 2>/dev/null"
    local output = TestRelease.readOutput(history)
    TestRelease.printDebug(output)
    is_like(output, "Fedora" .. TestRelease.release, "The first entry in Revision history points to the correct release. Got: " .. "\"" .. output .. "\"")
end


-- Check the correct version of the package - nice to have

----------------------------------------------------------------------------------

-- Test that Publican is able to build the book. - not needed

--function TestRelease.testBuild()
--    local pubsingle = "nice -n 15 publican build '--langs=en-US' '--formats=html-single' | grep 'Finished html-single'"
--    local output = TestRelease.readOutput(pubsingle)
--    output=string.trim(output)
--    print("debug: '" .. output .. "'")
--    is_equal(output, "Finished html-single", "Build was successful.")
--end


