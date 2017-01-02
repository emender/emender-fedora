-- TestPackages.lua - verify that all packages have correct names.
-- Copyright (C) 2014-2015 Pavel Vomacka
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

TestPackages = {
    -- required field
    metadata = {
        description = "Verify that all packages have correct names.",
        authors = "Pavel Vomacka",
        emails = "pvomacka@redhat.com",
        changed = "2017-01-01",
        tags = {"DocBook", "Release"},
    },
    requires = {"curl", "sqlite3", "unxz", "bunzip2"},
    repodirPath = "/tmp/repoDatabase/",
    docObj = nil,
    xmlObj = nil,
    pubObj = nil,
    --======================= Configurable variables =========================--
    product = "Fedora",
    version = "25",
    architectures = "x86_64", -- Order of architectures determines the order of repositories in which the test tries to find package.
    beta = 0,
    strict = 0,
    context = 0,
    packageWhiteList = "",
    lowestSupportedVersion = 23,
    --------------------------------- URLS -------------------------------------
    repoTable = {["f23-x86_64"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/23/Everything/x86_64/os"},
                 ["f23-debuginfo-x86_64"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/23/Everything/x86_64/debug"},
                 ["f23-i386"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/23/Everything/i386/os"},
                 ["f23-debuginfo-i386"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/23/Everything/i386/debug"},

                 ["f24-x86_64"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/24/Everything/x86_64/os"},
                 ["f24-debuginfo-x86_64"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/24/Everything/x86_64/debug/tree"},
                 ["f24-i386"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/24/Everything/i386/os"},
                 ["f24-debuginfo-i386"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/24/Everything/i386/debug/tree"},

                 ["f25-x86_64"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/25/Everything/x86_64/os"},
                 ["f25-debuginfo-x86_64"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/25/Everything/x86_64/debug/tree"},
                 ["f25-i386"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/25/Everything/i386/os"},
                 ["f25-debuginfo-i386"]={["url"]="http://mirrors.nic.cz/fedora/linux/releases/25/Everything/i386/debug/tree"}
				},
                 -- ["f23-debuginfo"]={["url"]="http://mirror.vutbr.cz/fedora/releases/23/Workstation/debug/os"},
                 -- FORMAT OF THIS TABLE IS:
                   -- ["dir_name"] = {["url"]="link"}
                        -- dir name has to start with abbreviation of product and version which is written in table below.
                        -- dir_name has to end with architecture name.
    ----------------------------- Abbreviations --------------------------------
    abbreviationsList = {["Fedora 23"] = "f23", ["Fedora 24"] = "f24", ["Fedora 25"] = "f25"},
    -- Format {[".extension"]="unziptool", [".ext2"]... }
    unzipTools = {[".xz"] = "unxz -c", [".bz2"] = "bunzip2 -d"},
    --========================================================================--
    packageNamesPackageTag = {},
    packageNamesCommandTag = {},
    availablePackages = {},
    allRepositories = {},
    -- List of commands written after command yum, which are useful for this test.
    yumdnfCommands = {"install", "search", "remove",
                "upgrade", "downgrade", "erase", "update",
                "reinstall", "group"},
    groupCommands = {"install", "remove", "upgrade"},
    packagesBlacklist = {"all"},
    -- Table which is used to convert architecture name from package to architecture name we are using.
    architecturesTable = {["x86_64"]="x86_64", ["i686"]="i386", ["i586"] = "i386", ["amd64"]="x86_64", ["i386"] = "i386", ["noarch"]= nil}, -- noarch option just for sure that we cover all posibilities.
}


--
--- Prints information about current test configuration.
--
function TestPackages.printInformation()
    local content = "Current test configuration: \n\tProduct: " .. TestPackages.product .. "\n\tVersion: "
                   .. TestPackages.version .. "\n\tBeta: " .. TestPackages.beta

    -- Print information about test configuration.
    warn(content)
end


--
--- Converts comma-separated string into the table, where each item in the table represents one string separated by commas.
--
--  @param commaSeparated
function TestPackages.convertCommaSeparatedIntoTable(commaSeparated)
    local tempTable = {}
    local getParts = commaSeparated:gmatch("([_%w%-]+)")

    for part in getParts do
        table.insert(tempTable, part)
    end

    return tempTable
end


--
--- Prepares tables with allowed yum commands and black list of yum command.
--  Preparation means converting table into [value]=true format.
--
function TestPackages.prepareTables()
    TestPackages.yumdnfCommands = table.setValueToKey(TestPackages.yumdnfCommands)
    TestPackages.packagesBlacklist = table.setValueToKey(TestPackages.packagesBlacklist)
    TestPackages.groupCommands = table.setValueToKey(TestPackages.groupCommands)
end


--
--- Parses type of package from its name. If the package name starts with '@' or is enclosed in double quotes
--  then it is name of group package. If the package ends with '-debuginfo', then it is debug info.
--  Otherwise, it is normal package name.
--
--  @param package name
--  @return string with type of package.
function TestPackages.getTypeOfPackage(package)
    if package:match("^@") or package:match("\".*\"$") then
        -- If package name starts with '@' or if it is enclosed in double
        --      quotes then it is name of group.
        return "group"
    elseif package:match("%-debuginfo$") then
        -- If package name ends with '-debuginfo' then it is name of
        --      debuginfo package.
        return "debuginfo"
    else
        -- In all other cases it is common package name.
        return "normal"
    end
end



--
--- Parses package names with version, architecture, etc.
--  And even those packages which don't have all information, but some.
--
--  @param package name
--  @return table with all information of package.
function TestPackages.parsePackageName(package)
    local reversedName = package:reverse()
    local list = {}
    local arch = ""
    local version = ""
    local name = ""
    local packageFunction = nil

    if package:match("^[%*_%w]+%.rpm") then
        -- Special case when there is package name in this form: "pckgname.rpm"
        packageFunction = reversedName:gmatch("(mpr)%.([^%.]*)")
        _, name = packageFunction()
    elseif package:match(".+%.rpm$") then
        -- If name of package ends by rpm.
        packageFunction = reversedName:gmatch("(mpr)%.([^%.]*)%.([^%-]*)%-([^%-]*)%-(.*)")
        _, arch, _, version, name = packageFunction()
    elseif reversedName:match("^[^%.]*%.[^%-]*%-[^%-]*%-.*") then
        -- For cases when rpm is no included.
        packageFunction = reversedName:gmatch("([^%.]*)%.([^%-]*)%-([^%-]*)%-(.*)")
        arch, _, version, name = packageFunction()
    elseif package:match("%-[%d%.]+%-[%d%.]+$") then
        -- For names which include only version, architecture and name of package.
        packageFunction = reversedName:gmatch("([^%-]*)%-([^%-]*)%-(.*)")
        _, version, name = packageFunction()
    elseif package:match("%-[%d%.]+$") then
        -- For packages only with version and name.
        packageFunction = reversedName:gmatch("([^%-]*)%-(.*)")
        version, name = packageFunction()
    elseif package:match("%.[ixa][3856no][86da][6_r][64c]?[4h]?") then
        ------
        --  These architecture names are supported:
        --  ##### i386:
        --  i386
        --  i586
        --  i686
        --
        --  ##### x64_86:
        --  x86_64
        --  amd64
        --
        --  ##### others:
        --  noarch

        packageFunction = reversedName:gmatch("(.*)%.(.*)")
        arch, name = packageFunction()
    else
        name = reversedName
    end

    table.insert(list, name:reverse())
    table.insert(list, version:reverse())
    table.insert(list, arch:reverse())
    table.insert(list, package)

    return list
end


--
--- Finds all package names in package tags.
--
--  @return table with package names and other information.
function TestPackages.findInPackageTag()
    -- Print information
    warn("Searching for package names in package tags ...")

    -- Find content of all package tags and save it into table.
    local packages = TestPackages.xmlObj:getElements("package")

    -- Handle situation that there is no package.
    if not packages then return nil end

    -- Prepare empty list for packages.
    local list = {}

    -- Create list for storing packages which are already in list.
    local packageNames = {}

    -- Go through all packages and process them.
    for _, package in ipairs(packages) do
        -- Check whether we already stored package with this name, is so than skip it. (removes duplicates)
        if not packageNames[package] then
            packageNames[package] = true

            local packageType = TestPackages.getTypeOfPackage(package)

            -- Package must not start with dot or hyphen.
            if not package:match("^[%.%-]") then
                -- Parse package name and take from it all information.
                local packageInfo = TestPackages.parsePackageName(package)

                -- content = {pckg_name, pckg_version, pckg_arch, whole_pckg_name, context, pckg_type}
                local content = {packageInfo[1], packageInfo[2], packageInfo[3], packageInfo[4], context, packageType}

                -- Check whether name contains at least one alphanumeric character.
                if package:match("%w") then
                    table.insert(list, content) end
            end
        end
    end

    -- Return table with packages and information about them.
    return list
end


--
--- Finds all package names in command tags.
--
--  @return list with package names and other information.
function TestPackages.findInCommandTag()
    -- Print information
    warn("Searching for package names in command tags ...")

    -- Get list of all commands
    local commands = TestPackages.xmlObj:getElements("command")
    if not commands then return nil end

    -- Prepare list for package names from command tag and information about them.
    local packages = {}

    -- Create list for storing packages which are already in list.
    local packageNames = {}

    -- Go through all commands
    for _, command in ipairs(commands) do
        -- Type of packages. Correct values can be:
            -- "normal"
            -- "group"
            -- "debuginfo"
        local packageType = "normal"
        -- Save whole command because of printing.
        local commandBackup = command

        -- If in command is word "debuginfo-install" then look at it.
        if command:match(".*debuginfo%-install .*") then
            command = command:gsub(".*debuginfo%-install ", "")
            for word in command:gmatch("[*%w_-]+") do

                -- If word doesn't start with dash, add this package with its context into list.
                if word:match("^[^%-].*") then
                    packageType = "debuginfo"
                    local packageInfo = {}
                    table.insert(packageInfo, word)
                    table.insert(packageInfo, "")
                    table.insert(packageInfo, "")
                    table.insert(packageInfo, word)

                    -- content = {pckg_name, pckg_version, pckg_arch, whole_pckg, context, pckg_type}
                    local content = {packageInfo[1], packageInfo[2], packageInfo[3], packageInfo[4], commandBackup, packageType}

                    -- Check whether this package is not in the list yet.
                    if not packageNames[packageInfo[1]] then
                        packageNames[packageInfo[1]] = true
                        table.insert(packages, content)
                    end
                end
            end

        -- If in command is word "yum" or "dnf" then look at it.
        elseif command:match(".*yum .*") or command:match(".*dnf .*") then
            local wordCounter = 1
            local inDoublequotes = false
            local groupInstall = false
            if command:match(".*yum .*") then
                command = command:gsub(".*yum ", "")
            elseif command:match(".*dnf .*") then
                command = command:gsub(".*dnf ", "")
            end

            local wholeGroup = ""

            for word in command:gmatch("%S+") do
                local skip = false

                -- If word doesn't start with '-' or '/', start working.
                if word:match("^[^%-/]") then
                    wordCounter = wordCounter + 1
                    if wordCounter == 2 then
                        if not TestPackages.yumdnfCommands[word] then break end
                        if word:match("group") then groupInstall = true end
                    elseif wordCounter >= 3 then
                        -- Group install. We need to hadle these situations:
                        -- yum(dnf) install @"KDE Desktop"
                        -- yum(dnf) install @kde-desktop
                        -- yum(dnf) group install @"Virtualization Tools"
                        -- yum(dnf) group install "Virtualization Tools"
                        -- yum(dnf) group install @kde-desktop
                        -- yum(dnf) group install kde-desktop
                        -- yum(dnf) group install KDE
                        if groupInstall and wordCounter == 3 and TestPackages.groupCommands[word] then
                            skip = true
                        elseif word:match("^@.*") or groupInstall or inDoublequotes then
                            packageType = "group"
                            -- It is necessary to concacenate words until next double quotes
                            if word:match("^@\".*") or word:match("^\".*") or inDoublequotes then
                                inDoublequotes = true
                                skip = true
                                wholeGroup = wholeGroup .. word .. " "

                                if word:match(".*\"$") then
                                    -- End of string quoted by double quotes.
                                    inDoublequotes = false
                                    skip = false
                                    word = wholeGroup
                                    wholeGroup = ""
                                end
                            end
                        end

                        -- Check whether the found word is not in black list or if it does not contain any of these characters: ()$#^& .
                        if TestPackages.packagesBlacklist[word] or word:match("[()%$#%^&]") then skip = true end
                    end

                    -- Add package name into list only if skip is set to false.
                    if not skip and wordCounter >= 3 then
                        -- Check whether package is not debuginfo.
                        if word:match("%-debuginfo$") then
                            packageType = "debuginfo"
                        end

                        local packageInfo = {}

                        if packageType == "normal" then
                            packageInfo = TestPackages.parsePackageName(word)
                        else
                            table.insert(packageInfo, word)
                            table.insert(packageInfo, "")
                            table.insert(packageInfo, "")
                            table.insert(packageInfo, word)
                        end

                        -- content = {pckg_name, pckg_version, pckg_arch, whole_pckg, context, pckg_type}
                        content = {packageInfo[1], packageInfo[2], packageInfo[3], packageInfo[4], commandBackup, packageType}

                        -- At least one alphanumeric character has to be in the package name.
                        -- Check whether this package is not in the list yet.
                        if word:match("[%w]") and not packageNames[packageInfo[1]] then
                            packageNames[packageInfo[1]] = true
                            table.insert(packages, content)
                        end

                        -- When there is not yum groupinstall then we can combine groups with packages.
                        if not groupInstall then packageType = "normal" end
                    end
                end
            end
        -- Turn off parameter which shows that we are installing groups.
        groupInstall = false
        end
    end

    -- Return the list of packages.
    return packages
end


--
--- Concatenates product and version. Then use it for getting abbreviation
--  of this product.
--
--  @return Abbreviation.
function TestPackages.getAbbreviation()
    local wholeProductName = TestPackages.product .. " " .. TestPackages.version
	return TestPackages.abbreviationsList[wholeProductName]
end


		--
--- Creates directory for storing files downloaded from repositories.
--
--  @param dirPath path to the directory which will be created
--  @return true if creating was successful, otherwise returns nil.
function TestPackages.prepareDir(dirPath)
    -- Prepare command for creating new directory.
    local command = "mkdir -p " .. dirPath

    -- Execute command and capture its output.
    execCaptureOutputAsString(command)

    -- Check if directory was created succesfully
    if not path.directory_exists(dirPath) then
        fail("Error creating directory: " .. dirPath)
        return nil
    end

    return true
end


--
--- Downloads file from 'link' and save it into 'target'.
--
--  @param target destination path
--  @param link to the file
--  @return true if donwloading was successful, otherwise returns nil.
function TestPackages.downloadFile(link, target)
    -- Compose command for downloading file from link.
    local command = "curl -# -f \"" .. link .. "\" > \"" .. target .. "\" 2>/dev/null"

      -- Execute the command and capture its output.
    execCaptureOutputAsString(command)

    if not path.file_exists(target) then
        fail(target .. " wasn't downloaded successfully.")
        return nil
    end

    return true
end


--
--- Parses information from metadata file.
--
--  @param mdFilePath path to the metadata file.
--  @param itemName name of item which it will find
--  @return item content or nil if there is no object with the name.
function TestPackages.parseMetadataFile(mdFilePath, itemName)
    -- Create xml object just for metadata file.
    local mdObj = xml.create(mdFilePath)
    local output = mdObj:parseXml("/newnamespace:repomd/newnamespace:data[@type=\"" .. itemName .. "\"]/newnamespace:location/@href", "http://linux.duke.edu/metadata/repo")

    -- If something was found return it.
    if output then
        return output[1]
    end

    -- Nothing was found.
    return nil
end



--
--- Unpacks files using unxz. The unpacked file will be saved in the same destination as source file.
--
--  @param dbFilePath destination path
--  @return true when unapcking is successful. nil otherwise.
function TestPackages.unpackFile(dbFilePath, ext)
    local unzip_cmd = TestPackages.unzipTools[ext]

    -- Compose command for unziping database and remove unuseful file. > \"" .. dbFilePath .. "\"
    local command = ""
    if ext == ".bz2" then
        command = unzip_cmd .. " \"" .. dbFilePath .. ext .. "\" && rm -f \"" .. dbFilePath .. ext .. "\""
    else
        command = unzip_cmd .. " \"" .. dbFilePath .. ext .. "\" > \"" .. dbFilePath .. "\" && rm -f \"" .. dbFilePath .. ext .. "\""
    end

    -- Execute command.
    execCaptureOutputAsString(command)

    -- Check whether file was unziped correctly.
    if not path.file_exists(dbFilePath) then
        fail("Database file was not unziped correctly.")
        return nil
    end

    return true
end


--
--- Get the extension of file.
--
-- @param str the path to the file
function TestPackages.getExtension(str)
    local getExt = str:gmatch(".*(%.[%w]+)")
    local ext = getExt()

    return ext

end


--
--- Donwloads and unpacks database file.
--
--  @param dbLink link to the database file
--  @param dbFilePath path to the database file.
--  @return true if everything is correct, nil otherwise.
function TestPackages.fetchDatabaseFile(dbLink, dbFilePath)
    local ext = TestPackages.getExtension(dbLink)

    -- Download database file.
    if not TestPackages.downloadFile(dbLink, dbFilePath .. ext) then
        return nil
    end

    -- Unpack database file.
    if not TestPackages.unpackFile(dbFilePath, ext) then
        return nil
    end

    -- Everything is OK.
    return true
end


--
--- Compares database checksum and check sum from metadata file.
--
--  @param dbFilePath path to the database file
--  @param mdFilePath path to the metadata file
function TestPackages.checkChecksums(dbFilePath, mdFilePath)
    -- Create xml object for metadata file.
    local mdObj = xml.create(mdFilePath)

    -- Parse xml file and take the first item from the result table.
    local mdChecksum = mdObj:parseXml("/newnamespace:repomd/newnamespace:data[@type=\"primary\"]/newnamespace:checksum/text()", "http://linux.duke.edu/metadata/repo")[1]

    -- Command which parse checksum from repomd.xml.
    command = "sqlite3 \"" ..dbFilePath.. "\" 'SELECT checksum FROM db_info;'"

    -- Execute command and capture its output.
    local dbChecksum = execCaptureOutputAsString(command)

    -- Compare checksums and return boolean value.
    return dbChecksum == mdChecksum
end


--
--- Removes every xml file which has 'comps-Server' in its name.
--
--  @param pathToTheDatabase path to the directory with database file.
function TestPackages.removeOldGroupXml(pathToTheDatabase)
    local command = "rm " .. pathToTheDatabase .. "/*comps-Server*.xml 2>/dev/null"
    execCaptureOutputAsString(command)
end



--
--- Runs SQL query because of getting all packages and its versions.
--
--  @param dbFilePath path to the database file.
--  @return list with packages {["name"]=version,...}
function TestPackages.getAvailablePackages(dbFilePath)
    -- Prepare empty list for packages.
    local packages = {}

    -- Compose and run command for getting all available packages.
    local command = "sqlite3 \"" .. dbFilePath .. "\" \"SELECT name, version FROM packages;\""
    local output = execCaptureOutputAsTable(command)

    -- Parse all found information and fetch from them name and version of package.
    for _, line in ipairs(output) do
        local getOutput = line:gmatch("(.*)|(.*)")
        name, version = getOutput()
        packages[name] = version
    end

    -- Return list of packages.
    return packages
end


--
--- Parse xml file with group names and returns list of groups
--
--  @param grFilePath path to the xml file with groups
--  @return list with group names. Nil when some problem occures.
function TestPackages.getAvailableGroups(grFilePath)
    if not grFilePath then
        return nil
    end

    -- Prepare empty list for groups.
    local groups = {}

    -- Create XML object for searching group names.
    local grObj = xml.create(grFilePath)
    local groups = grObj:parseXml("//group/id/text()|//group/name[1]/text()|//environment/id/text()|//environment/name[1]/text()")

    -- If at least on group was found then return converted list.
    if groups then
        return table.setValueToKey(groups)
    end

    return nil
end



--
--- Chooses repositories according to the current setting of architectures.
--  Donwload data from these repositories and fetch available group and package names.
--
--  @return list of repository names and list of package and group names.
function TestPackages.getAvailableGroupsPackages()
    -- Prepare variable for available groups and package names.
    local availablePackages = {}
    -- Prepare list for all used repository names.
    local allRepositories = {}

    -- Get abbreviation for current product and version.
    local productAbbreviation = TestPackages.getAbbreviation()

    for _, arch in ipairs(TestPackages.architectures) do
        for dirName, repoInfo in pairs(TestPackages.repoTable) do
            if dirName:match(arch .. "$") and dirName:match("^" .. productAbbreviation .. "%-.*") then
              allRepositories, availablePackages = TestPackages.handleThisRepository(allRepositories, availablePackages, dirName, repoInfo)
            end
        end
    end

    return allRepositories, availablePackages
end


--
--- Download data from current repository and fetch available group and package names.
--
--  @param allRepositories list of all repositories which was used
--  @param availablePackages list of lists with group and package names.
--  @param dirName name of repository - contains product and version abbreviation and architecture
--  @param repoInfo information about current repositories like URL.
--  @return actualized allRepositories and availablePackages
function TestPackages.handleThisRepository(allRepositories, availablePackages, dirName, repoInfo)
    -- Print information
    warn("Downloading data the '" .. dirName .. "' repository ...")

    local pathToTheDatabase = TestPackages.repodirPath .. dirName
    if not TestPackages.prepareDir(pathToTheDatabase) then
        return nil
    end

    local dbFilePath = pathToTheDatabase .. "/primary.sqlite" --db == database
    local mdFilePath = pathToTheDatabase .. "/repomd.xml"     --md == metadata
    local grFilePath = nil                                     --gr == group

    -- Create link to the metadata file.
    local mdLink = repoInfo["url"] .. "/repodata/repomd.xml"

    -- Download metadata file.
    if not TestPackages.downloadFile(mdLink, mdFilePath) then
        fail("Can't donwload metadata file for '" .. dirName .. "' repository." )
        return nil
    end

    -- Find the name of database file in metadata file.
    local dbLinkEnd = TestPackages.parseMetadataFile(mdFilePath, "primary_db")
    local dbLink =  repoInfo["url"] .. "/" .. dbLinkEnd

    -- Check whether database file exists, download it if it doesn't exist.
    -- In case that this file exists then check checksums
    -- for make sure that database file is up to date.
    if path.file_exists(dbFilePath) then
        -- Check checksums.
        if not TestPackages.checkChecksums(dbFilePath, mdFilePath) then
            --- Download database file and unpack it.
            if not TestPackages.fetchDatabaseFile(dbLink, dbFilePath) then
                fail("Can't donwload database file for '" .. dirName .. "' repository." )
                return nil
            end
        end
    else
        --- Download database file and unpack it.
        if not TestPackages.fetchDatabaseFile(dbLink, dbFilePath) then
            fail("Can't donwload database file for '" .. dirName .. "' repository." )
            return nil
        end
    end

        -- Fetch name of file which contains group information.
    local grLinkEnd = TestPackages.parseMetadataFile(mdFilePath, "group")

    -- In case that group file name was found then create target path for this file.
    if grLinkEnd then
        grFilePath = pathToTheDatabase .. grLinkEnd:gsub("repodata", "")
        local grLink = repoInfo["url"] .. "/" .. grLinkEnd

        -- Remove old group file.
        TestPackages.removeOldGroupXml(pathToTheDatabase)
        TestPackages.downloadFile(grLink, grFilePath)
    end

    -- Find groups and packages in downloaded files.
    local packages = {TestPackages.getAvailablePackages(dbFilePath), TestPackages.getAvailableGroups(grFilePath), dirName}

    -- Store current repository name
    table.insert(allRepositories, dirName)
    -- Store everything in table
    table.insert(availablePackages, packages)

    return allRepositories, availablePackages
end

--- Parses composed package name to the individual packages.
--
-- @return list with composed package list.
function TestPackages.parseComposedPackages(package)
  local list = {}

  -- Substitute {example,example2} from the package name
  local parseFunction = package:gmatch("(.*){(.*)}(.*)")
  local first, second, third = parseFunction()
  local counter = 0
  local pattern = "([%w%-]+)"

  -- Compose whole package name and save it to the list.
  if second:match("^,") or second:match(",,") or second:match(",$") then
    pattern = "([%w%-]*)"
  end

  for word in second:gmatch(pattern) do
    list[first .. word .. third] = true
  end

  -- Return list with the package names.
  return list
end


--
--- Function which finds whether the version is different in major or minor version.
--  According to the result this test will print warning or fail.
--
--  @param packageVersion version of package parsed from documentation.
--  @param currentVersion version of package from repository.
--  @return
function TestPackages.checkVersion(packageVersion, currentVersion)
    -- Parse version string by dots.
    local listPackageVersion = packageVersion:gmatch("[^%.]+")
    local listCurrentVersion = currentVersion:gmatch("[^%.]+")
    local counter = 0

    -- Go through all parts of version string
    while true do
        counter = counter + 1
        package = listPackageVersion()
        current = listCurrentVersion()

        -- If version parts are not same then return counter which says which part of counter is not same.
        if package ~= current then
            return counter
        -- If one or both version string ends, figure out which ends (both end == the same version, just one == not the same version)
        elseif not package or not current then
            if not package and not current then
                return 0
            else
                return -1
            end
        end
    end
end


--
--- Parses architecture from repository name.
--
--  @param dirName name of repository
--  @return architecture of current repository
function TestPackages.parseListArchitecture(dirName)
    local reversedDirName = dirName:reverse()

    local getOutput = reversedDirName:gmatch("([_%w]+)%-")
    local output = getOutput()

    return output:reverse()
end


--
--- Compare current list of package names with all available packages and groups.
--  It also prints fail, warn or pass messages.
--
--  @param list current list with package and group names from document
function TestPackages.checkPackageList(list)
    -- Check whether list is not empty.
    if table.isEmpty(list) then
        pass("No relevant commands found.")
        return
    end

    -- Variable description:
        -- package = current package which was found in book
        -- realPackage = existing package from package database
        -- listOfPackages = list of packages available in current repository
        -- packageListCounter = counter which sets number of used repositories.

    for i, content in ipairs(list) do
        local package = content[1]
        local packageVersion = content[2]
        local packageArchitecture = TestPackages.architecturesTable[content[3]]
        local originalPackage = content[4]
        local packageType = content[6]
        local found = false
        local notCurrentMajorVersion = false
        local notCurrentMinorVersion = false
        local packageExample = false
        local explanation = ""
        local packageListCounter = 0
        local allRepositories = {}

        -- If package name is foo, bar, foobar or contains 'package' - it's probably not the name of real package.
        if package == "foo" or package:match(".*foobar.*") or package == "bar" or package:match("package") or package:match("group") then
            packageExample = true
            explanation = explanation .. " However, this may be an example package name."
        end

        -- If packages type is group.
        if packageType == "group" then
            explanation = explanation .. " This package name is name of group."
            -- Prepare group name for comparing with existing group names.
            -- It is necessary to remove all non-alphabetical characters ('@', etc.) from both sides of string.
            package = string.trimString(package)

            --- Compare current package with all lists of available groups.
            for _, listOfPackages in ipairs(TestPackages.availablePackages) do
                -- If package was found in last comparsion, this cycle will end.
                if found then break end

                -- Add this repository name to the list of repositories.
                table.insert(allRepositories, listOfPackages[3])

                -- If list is nil then there is no xml file with group names.
                if listOfPackages[2] and listOfPackages[2][package] then
                    -- Set found as true.
                    found = true
                    break
                end
            end

        -- If package name ends with * then it is necessary to use patterns.
        elseif package:match(".%*$") then
            -- Remove star from package name.
            package = package:sub(1, #package -1)
            -- Substitute hyphen.
            package = package:gsub("%-", "%%-")

            -- Compare current package with all list of available packages.
            for _, listOfPackages in ipairs(TestPackages.availablePackages) do
                -- If package was found in last comparsion, this cycle will end.
                if found then break end

                -- Add this repository name to the list of repositories.
                table.insert(allRepositories, listOfPackages[3])

                for originalPackage, name in pairs(listOfPackages[1]) do
                    if originalPackage:match("^".. package .. ".*") then
                        -- Set found as true.
                        found = true
                        break
                    end
                end
            end

        -- Other package names, normal names, composed names.
        else
            -- Current package is debuginfo.
            local debugInfo = false

            -- Add "-debuginfo" suffix to all packages which are installed using debuginfo command.
            if packageType == "debuginfo" then
                debugInfo = true
                if not package:match("%-debuginfo$") then package = package .. "-debuginfo" end
            end

            -- Compare current package with all lists of available packages.
            for _, listOfPackages in ipairs(TestPackages.availablePackages) do
                -- Find package in list of available packages and check architecture of this package.
                local listArchitecture = TestPackages.parseListArchitecture(listOfPackages[3])

                -- If the package is already found, the loop will end.
                if found then break end

                -- Add this repository name to the list of repositories.
                table.insert(allRepositories, listOfPackages[3])

                -- Normal packages, not debuginfo.
                if not debugInfo then
                    -- Check whether this package is not composed package.
                    if package:match("[{}]") then
                        local composedPackages = TestPackages.parseComposedPackages(package)
                        local notFound = false

                        -- Go through all packages in composed package name.
                        for onePackage in pairs(composedPackages) do
                            -- Try to find package name. If one of these packages is not found
                            -- then whole composed name is marked as not correct.
                            if not listOfPackages[1][onePackage] then
                                notFound = true
                            end
                        end

                        if not notFound then found = true end

                    elseif listOfPackages[1][package] and (not packageArchitecture or packageArchitecture == listArchitecture) then
                        -- Check version of package.
                        if packageVersion ~= "" then
                            local returnValue = TestPackages.checkVersion(packageVersion, listOfPackages[1][package])

                            if returnValue > 1 then
                                notCurrentMinorVersion = true
                                -- WARN
                            elseif returnValue > 0 then
                                notCurrentMajorVersion = true
                                -- FAIL
                            end

                            -- Add explanation of current version
                            explanation = explanation .. " Current version is: '" .. listOfPackages[1][package] .. "'."
                        end
                        found = true
                        break
                    end

                -- Debug info packages.
                elseif listOfPackages[3]:match("debuginfo") then
                    if listOfPackages[1][package] and (not packageArchitecture or packageArchitecture == listArchitecture) then
                        found = true
                        break
                    end
                end
            end
        end

        -- Adding context .. in this case whole command where package name was found.
        if TestPackages.context ~= 0 and content[5] ~= "" then
            explanation = explanation .. " Found in: '" .. content[5] .. "'."
        end

        -- Boolean which set whether we are in optional repository.
        local optional = allRepositories[#allRepositories]:match("%-opt%-")

        -- If package was not found in any repository print it as fail.
        if not found then
            local repositoriesString = table.concat(allRepositories, ", ")
            if TestPackages.packageWhiteList[originalPackage] then
                pass("Package **" .. originalPackage .. "** not found in repositories, but it is on the white list.")
            elseif packageExample then
                warn("Package **" .. originalPackage .. "** not found in " .. repositoriesString .. "." .. explanation)
            else
                fail("Package **" .. originalPackage .. "** not found in " .. repositoriesString .. "." .. explanation)
            end
        else
            if notCurrentMajorVersion then
                fail("Package **" .. originalPackage .. "** found in " .. allRepositories[#allRepositories] .. "." .. explanation)
            elseif optional or notCurrentMinorVersion then
                warn("Package **" .. originalPackage .. "** found in " .. allRepositories[#allRepositories] .. "." .. explanation)
            else
                pass("Package **" .. originalPackage .. "** found in " .. allRepositories[#allRepositories] .. "." .. explanation)
            end
        end
    end
end

--
--- This function is called as very first.
--
function TestPackages.setUp()
    -- Load libraries.
    dofile(getScriptDirectory() .. "lib/xml.lua")
    dofile(getScriptDirectory() .. "lib/publican.lua")
    dofile(getScriptDirectory() .. "lib/docbook.lua")
    dofile(getScriptDirectory() .. "lib/infofile.lua")

    TestPackages.printInformation()

    -- Check whether this version of fedora is supported.
    if tonumber(TestPackages.version) < TestPackages.lowestSupportedVersion then
        fail("This version ('" .. TestPackages.version .. "') of Fedora is not supported.")
        return
    end

    TestPackages.architectures = TestPackages.convertCommaSeparatedIntoTable(TestPackages.architectures)
    TestPackages.packageWhiteList = TestPackages.convertCommaSeparatedIntoTable(TestPackages.packageWhiteList)
    TestPackages.packageWhiteList = table.setValueToKey(TestPackages.packageWhiteList)
    TestPackages.prepareTables()

    -- Create publican object.
    TestPackages.pubObj = publican.create("publican.cfg")

    -- Find main file of the document.
    local mainFile = TestPackages.pubObj:findMainFile()

    -- Create xml object.
    TestPackages.xmlObj = xml.create(mainFile)

    -- Create docbook object.
    TestPackages.docObj = docbook.create(mainFile)

    -- Find all packages in package tags.
    TestPackages.packageNamesPackageTag = TestPackages.findInPackageTag()

    -- Find all packages in command tags.
    TestPackages.packageNamesCommandTag = TestPackages.findInCommandTag()



    -- If there is at least one package then download all available packages.
    if not table.isEmpty(TestPackages.packageNamesPackageTag) or not table.isEmpty(TestPackages.packageNamesCommandTag) then
        TestPackages.allRepositories, TestPackages.availablePackages = TestPackages.getAvailableGroupsPackages()
    end
end



--
--- Tests packages from package tag.
--
function TestPackages.testPackageTag()
    TestPackages.checkPackageList(TestPackages.packageNamesPackageTag)
end


--
--- Tests packages from command tag.
--
function TestPackages.testCommandTag()
    TestPackages.checkPackageList(TestPackages.packageNamesCommandTag)
end
