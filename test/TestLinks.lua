-- TestLinks.lua - a test to verify that all external links are functional
-- Copyright (C) 2014-2015 Jaromir Hradilek, Pavel Vomacka

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


TestLinks = {
    metadata = {
        description = "Verify that all external links are functional.",
        authors = "Jaromir Hradilek, Pavel Vomacka",
        emails = "jhradilek@redhat.com, pvomacka@redhat.com",
        changed = "2015-12-21",
        tags = {"DocBook", "Release"}
    },
    xmlObj = nil,
    pubObj = nil,
    allLinks = nil,
    language = "en-US",
    requires = {"curl", "xmllint", "xmlstarlet"},
    exampleList = {"example%.com", "example%.edu", "example%.net", "example%.org",
                 "localhost", "127%.0%.0%.1", "::1"}
}

-- NOTE: mallard library missing


--
--- Parse links from the document.
--
--  @return table with links
function TestLinks.findLinks()
    return TestLinks.xmlObj:getAttributesOfElement("url", "ulink")
end


--
--- Convert table with links to the string where links are separated by new line.
--  This format is used because of bash functions.
--
--  @return string which contains all links separated by new line.
function TestLinks.convertListForMultiprocess()
    local convertedLinks = ""

    -- Go through all links and concatenate them. Put each link into double quotes
    -- because of semicolons in links which ends bash command.
    for _, link in pairs(TestLinks.allLinks) do
        -- Skip every empty line.
        if not link:match("^$") then
            convertedLinks = convertedLinks .. "\"" .. link .. "\"\n"
        end
    end

    -- Remove last line break.
    return convertedLinks:gsub("%s$", "")
end


--
--- Compose command in bash which tries all links using more processes.
--
--  @param links string with all links separated by new line.
--  @return composed command in string
function TestLinks.composeCommand(links)

    local command =  [[ checkLink() {

    curl -4ILks --post302 --connect-timeout 5 --retry 1 --max-time 10 -A 'Mozilla/5.0 (X11; Linux x86_64; rv:31.0) Gecko/20100101 Firefox/31.0' $1 > /dev/null
    echo "$1______$?"
    }

    export -f checkLink
    echo -e ']] .. links .. [[' | xargs -d'\n' -n1 -P0 -I url bash -c 'echo `checkLink url`' ]]
    -- This calls curl. Curl with these parameters can run parallelly (as many processes as OS allows).
    -- Maximum time for each link is 5 seconds. Output of function checkLink is:
    --                                                        tested_url______exit_code

    return command
end


--
--- Runs command which checks all links and then parse output of this command.
--  In the ouput table is information about each link in this format: link______exitCode.
--  link is link, exitCode is exit code of curl command, it determines which error occured.
--  These two information are separated by six underscores.
--
--  @param links string with links separated by new line
--  @return list with link and exit code
function TestLinks.checkLinks(links)
    local list = {}

    local output = execCaptureOutputAsTable(TestLinks.composeCommand(links))

    for _, line in ipairs(output) do
        local link, exitCode = line:match("(.+)______(%d+)$")
        list[link] = exitCode
    end

    return list
end

--
--- Function that find all links to anchors.
--
--  @param link
--  @return true if link is link to anchor, otherwise false.
function TestLinks.isAnchor(link)
    -- If link has '#' at the beginning or if the link doesnt starts with protocol and contain '#' character
    -- then it is link to anchor.
    if link:match("^#") or (not link:match("^%w%w%w%w?%w?%w?://") and link:match("#")) then
        return true
    end

    return false
end


--
--- Checks whether link has prefix which says that this is mail or file, etc.
--
--  @param link
--  @return true if link is with prefix or false.
function TestLinks.mailOrFileLink(link)
    if link:match("^mailto:") or link:match("^file:") or link:match("^ghelp:")
        or link:match("^install:") or link:match("^man:") or link:match("^help:") then
        return true
    else
        return false
    end
end


--
--- Checks whether the link corresponds with one of patterns in given list.
--
--  @param link
--  @param list
--  @return true if pattern in list match link, false otherwise.
function TestLinks.isLinkFromList(link, list)
    -- Go through all patterns in list.
    for i, pattern in ipairs(list) do
        if link:match(pattern) then
            -- It is example or internal link.
            return true
        end
    end
    return false
end


--
--- Function whihch runs first. This is place where all objects are created.
--
function TestLinks.setUp()
    -- Load libraries.
    dofile(getScriptDirectory() .. "lib/xml.lua")
    dofile(getScriptDirectory() .. "lib/publican.lua")

    -- Create publican object.
    TestLinks.pubObj = publican.create("publican.cfg")

    -- Create xml object.
    TestLinks.xmlObj = xml.create(TestLinks.pubObj:findMainFile())

    -- Print information about searching links.
    warn("Searching for links in the book ...")
    TestLinks.allLinks = TestLinks.findLinks()
end


--
--- Tests all links and print output of test.
--
function TestLinks.testAllLinks()
    if table.isEmpty(TestLinks.allLinks) then
        pass("No links found.")
        return
    end

    -- Convert list of links into string and then check all links using curl.
    local checkedLinks = TestLinks.checkLinks(TestLinks.convertListForMultiprocess())

    -- Go through all links and print the results out.
    for link, exitCode in pairs(checkedLinks) do
        if TestLinks.isAnchor(link) then
            warn(link .. " - Anchor")
        elseif TestLinks.mailOrFileLink(link) then
            -- Mail or file link - warn
            warn(link)
        elseif TestLinks.isLinkFromList(link, TestLinks.exampleList) then
            -- Example or localhost - OK
            warn(link .. " - Example")
        else
            -- Check exit code of curl command.
            if exitCode == "0" then
                pass(link)
            else
                fail(link)
            end
        end
    end
end
