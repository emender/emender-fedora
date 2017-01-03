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
        changed = "2016-11-19",
        tags = {"DocBook", "Release"}
    },
    xmlObj = nil,
    pubObj = nil,
    allLinks = nil,
    language = "en-US",
    forbiddenLinks = nil,
    forbiddenLinksTable = {},
    requires = {"curl", "xmllint", "xsltproc"},
    exampleList = {"example%.com", "example%.edu", "example%.net", "example%.org",
                 "localhost", "127%.0%.0%.1", "::1"},
    HTTP_OK_CODE = "200",
    FTP_OK_CODE = "226",
    curlCommand = "curl -4Ls --insecure --post302 --connect-timeout 5 --retry 5 --retry-delay 3 --max-time 20 -A 'Mozilla/5.0 (X11; Linux x86_64; rv:31.0) Gecko/20100101 Firefox/31.0' ",
    curlDisplayHttpStatusAndEffectiveURL = "-w \"%{http_code} %{url_effective}\" -o /dev/null "
}

--
--- Parse links from the document.
--
--  @return table with links
function TestLinks.findLinks()
    local links  = TestLinks.xmlObj:getAttributesOfElement("href", "link")
    local ulinks = TestLinks.xmlObj:getAttributesOfElement("url",  "ulink")
    if links then
        warn(#links .. " link tag(s) found.")
    else
        warn("No link tag found.")
    end
    if ulinks then
        warn(#ulinks .. " ulink tag(s) found.")
    else
        warn("No ulink tag found.")
    end
    if links then
        if ulinks then
            return table.appendTables(links, ulinks)
        else
            return links
        end
    else
        return ulinks
    end
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

    echo -n "$1 "
    curl -4Ls --insecure --post302 --connect-timeout 5 --retry 5 --retry-delay 3 --max-time 20 -A 'Mozilla/5.0 (X11; Linux x86_64; rv:31.0) Gecko/20100101 Firefox/31.0' -w "%{http_code} %{url_effective}" -o /dev/null $1 | tail -n 1
    }

    export -f checkLink
    echo -e ']] .. links .. [[' | xargs -d'\n' -n1 -P0 -I url bash -c 'echo `checkLink url`' ]]
    -- This calls curl. Curl with these parameters can run parallelly (as many processes as OS allows).

    return command
end


--
--- Runs command which tries all links and then parse output of this command.
--
--  @param links string with links separated by new line
--  @return list with link and exit code
function TestLinks.tryLinks(links)
    local list = {}

    local output = execCaptureOutputAsTable(TestLinks.composeCommand(links))

    for _, line in ipairs(output) do

        -- line should consist of three parts separated by spaces:
        -- 1) original URL (as written in document)
        -- 2) HTTP code (200, 404 etc.)
        -- 3) final URL (it could differ from the original URL if request redirection has been performed)
        local originalUrl, httpCode, effectiveUrl = line:match("(%g+) (%d+) (.+)$")
        local result = {}
        result.originalUrl = originalUrl
        result.effectiveUrl = effectiveUrl
        result.httpCode = httpCode
        list[effectiveUrl] = result
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
    if path.file_exists("publican.cfg") then
        TestLinks.pubObj = publican.create("publican.cfg")

        -- Create xml object.
        TestLinks.xmlObj = xml.create(TestLinks.pubObj:findMainFile())

        -- Print information about searching links.
        warn("Searching for links in the book ...")
        TestLinks.allLinks = TestLinks.findLinks()
    else
        fail("publican.cfg does not exist")
    end

    if TestLinks.forbiddenLinks then
        warn("Found forbiddenLinks CLI option: " .. TestLinks.forbiddenLinks)
        local links = TestLinks.forbiddenLinks:split(",")
        for _,link in ipairs(links) do
            warn("Adding following pattern into black list: " .. link)
            -- insert into table
            TestLinks.forbiddenLinksTable[link] = link
        end
    end
end


--
-- Replaces the ftp:// protocol specification by http://
--
function ftp2httpUrl(link)
    if link:startsWith("ftp://") then
        return link:gsub("^ftp://", "http://")
    else
        return link
    end
end



--
-- Check if one selected link is accessible.
--
function tryOneLink(linkToCheck)
    local command = TestLinks.curlCommand .. TestLinks.curlDisplayHttpStatusAndEffectiveURL .. linkToCheck .. " | tail -n 1"
    local output = execCaptureOutputAsTable(command)
    -- this function returns truth value only if:
    -- output must be generated, it should contain just one line
    -- and on the beginning of this line is HTTP status code 200 OK
    return output and #output==1 and string.startsWith(output[1], TestLinks.HTTP_OK_CODE)
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
    local checkedLinks = TestLinks.tryLinks(TestLinks.convertListForMultiprocess())

    -- Go through all links and print the results out.
    for linkValue, result in pairs(checkedLinks) do
        local exitCode = result.httpCode
        local originalUrl = result.originalUrl
        local effectiveUrl = result.effectiveUrl
        if TestLinks.isAnchor(originalUrl) then
            warn(originalUrl .. " - Anchor")
        elseif TestLinks.mailOrFileLink(originalUrl) then
            -- Mail or file link - warn
            warn(originalUrl)
        elseif TestLinks.isLinkFromList(originalUrl, TestLinks.exampleList) then
            -- Example or localhost - OK
            warn(originalUrl .. " - Example")
        else
            -- Check exit code of curl command.
            if exitCode == TestLinks.HTTP_OK_CODE or exitCode == TestLinks.FTP_OK_CODE then
                -- special case for FTP
                if linkValue:startsWith("ftp://") then
                    local htmlLink = ftp2httpUrl(linkValue)
                    if tryOneLink(htmlLink) then
                        -- ftp link is ok AND http link is ok as well
                        -- -> display suggestion to writer that he/she should use http:// instead of ftp://
                        fail("Please use HTTP protocol instead of FTP. Current: " .. linkValue .. " Suggested: " .. htmlLink)
                    else
                        -- only ftp:// link is accessible
                        pass(linkValue)
                    end
                else
                    pass(linkValue)
                end
            else
                -- the URL is not accessible -> the test should fail
                -- if the request has been redirected to another URL, show the original URL and redirected one
                if originalUrl ~= effectiveUrl then
                    fail("URL in document: " .. originalUrl .. " Redirected URL: " .. effectiveUrl)
                else
                -- no redirection -> show the original URL as is written in the document
                    fail("URL to check: " .. originalUrl, originalUrl)
                end
            end
        end
    end
end


--
--- Test whether some links does not match forbidden patterns.
--
function TestLinks.testForbiddenLinks()
    if not TestLinks.forbiddenLinks then
        warn("--XforbiddenLinks is not used, skipping")
        return
    end

    if table.isEmpty(TestLinks.allLinks) then
        pass("No links found.")
        return
    end

    for _,link in ipairs(TestLinks.allLinks) do
        for __,forbiddenLink in pairs(TestLinks.forbiddenLinksTable) do
            if string.find(link, forbiddenLink, 1, true) then
                fail(link .. " is forbidden")
            end
        end
    end
end
