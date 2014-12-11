-- TestPreRelease.lua - Test if a book is ready for a GA and beta release.
-- Copyright (C) 2014 Barbora Ancincova

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


-- NOTE: this test must be run in the directory with the publican.cfg file. The release variable is equal to the name of the git branch (for example 7.1_Beta) and must be specified by the --X option when running emender - emend --Xrelease=7.1_Beta.

TestPreRelease = {
    metadata = {
        description = "Test if a book is ready for a GA or Beta release.",
        authors = "Barbora Ancincova",
        emails = "bancinco@redhat.com",
        changed = "2014-10-10",
        tags = {"Sanity", "XML"}
    },
    requires = {"git", "grep", "xmlstarlet","xmllint"},
    --TODO - debug = 0
    language = "en-US",
    brand = "RedHat-201405",
    git_branch = "docs-rhel-6"
}

function TestPreRelease.setUp()
	TestPreRelease.verifyPath()
	TestPreRelease.rootfile = TestPreRelease.findStartFile()
	TestPreRelease.majorver = string.sub(TestPreRelease.release, 1, 1)
	TestPreRelease.generateMinorver()
	TestPreRelease.generateGA_Beta()
	if not TestPreRelease.verifyUsedFiles() then return end
	TestPreRelease.testBranch()
end

-- Generate the TestPreRelease.minorver global variable
function TestPreRelease.generateMinorver()
       local minorver = string.match(TestPreRelease.release, "%.(%d+)[%-_]")
       --print(minorver)
       TestPreRelease.minorver = minorver
end

-- Generate the TestPreRelease.ga_beta global variable
function TestPreRelease.generateGA_Beta()
	local ga_beta = string.match(TestPreRelease.release, "[%-_](%w+)")
	--print(ga_beta)
	TestPreRelease.ga_beta = ga_beta
end

--Verify that the en-US/Author_Group.xml, en-US/Book_Info.xml files exist.
function TestPreRelease.verifyUsedFiles()
	if not TestPreRelease.checkFile("en-US/Author_Group.xml", "er") then
    		fail("The Author_Group.xml file does not exist.")
    		return false
  	end
	if not TestPreRelease.checkFile("en-US/Book_Info.xml", "er") then
    		fail("The Book_Info.xml file does not exist.")
    		return false
  	end
	if not TestPreRelease.checkFile("en-US/Revision_History.xml", "er") then
    		fail("The Revision_History.xml file does not exist.")
    		return false
  	end
	return true
end

-- Test if you are in the correct branch for example 7.0_GA, 7.1_Beta.
function TestPreRelease.testBranch()
	local find_gitcongif = "test -f .git/config;echo $?"
       	local output = TestPreRelease.readOutput(find_gitcongif)
	if output == "0" then
		local git = "git rev-parse --abbrev-ref HEAD"
		local output = TestPreRelease.readOutput(git)
--		print("debug: '" .. output .. "'")
		is_equal(output, TestPreRelease.release, "The git branch is correct: Got: " .. "\"" .. output .. "\"")
	else warn("Could not verify the correct git branch. Either the test is ran in a non-git repository or in other branch then Beta or GA.")
	end
end

--- Find the name of the first file of a book.

-- @return Returns path of a file where the book starts.
function TestPreRelease.findStartFile()
  -- Checks if publican.cfg exists.
  -- If it doesn't then ends because it isn't in a DocBook format.
  if not TestPreRelease.checkFile(TestPreRelease.addPathPart(TestPreRelease.path, "publican.cfg"), "e") then
    fail("The book is not in the DocBook format.")
    return nil
  end
 
  -- Lists the files in language directory.
  local command = "ls " .. TestPreRelease.addPathPart(TestPreRelease.path, TestPreRelease.language .. "/*.ent")
 
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
--function TestPreRelease.getPath(file)
--	local path = TestPreRelease.addPathPart(TestPreRelease.path, file)
--	if not TestPreRelease.checkFile(path, "ew") then
--    		fail("The" .. file .. "file does not exist.")
--    		return nil
--	end
--	return path
--end

-- Function which checks if path is set or not.
function TestPreRelease.verifyPath()
  if TestPreRelease.path then
    if not TestPreRelease.checkFile(TestPreRelease.path, "ed") then
      fail("Book directory doesn't exist.")
    end
  else
    -- Set empty string as a path.
    TestPreRelease.path = ""
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
function TestPreRelease.checkFile(file_path, test_type)
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
function TestPreRelease.addPathPart(path, add_string)
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

function TestPreRelease.readOutput(command)
	local fd = io.popen(command)
	local output = fd:read('*all')
	fd:close()
	output=string.trim(output)
	return output
end

--- Tests for both releases

-- Check that remarks are disabled.
function TestPreRelease.testRemarks()
       	local remark_tag = "grep -q 'show_remarks:' publican.cfg;echo $?"
       	local output = TestPreRelease.readOutput(remark_tag)
       	if output== "1" then
--		print("Remarks are disabled.")
	end
	if output == "0" then
		local remarks = "grep -q 'show_remarks: 0' publican.cfg;echo $?"
       		local output = TestPreRelease.readOutput(remarks)
--      	print("debug: '" .. output .. "'")
       		is_equal(output, "0", "Remarks are disabled.")
	end	
end

-- Check the correct brand
-- TODO modify the sed command to return also 'RedHat'
function TestPreRelease.testBrand()
	local brand = "grep brand publican.cfg | sed 's/brand:\\s*\"*\\([^\"]*\\)\"*/\\1/'"
       	local output = TestPreRelease.readOutput(brand)
--      print("debug: '" .. output .. "'")
       	is_equal(output, TestPreRelease.brand, "The brand specified in the publican.cfg file is correct.  Got: " .. "\"" .. output .. "\"")
end

-- Check the correct git-branch in publican.cfg
-- TODO is this needed? there is no git_branch in generated publican.cfg → kdyz nenajde tak taky ok?
function TestPreRelease.testGitBranch()
	local find_gitcongif = "test -f .git/config;echo $?"
       	local output = TestPreRelease.readOutput(find_gitcongif)
	if output == "0" then
		local git_branch = "grep git_branch publican.cfg | sed 's/git_branch:\\(.*\\)/\\1/'"
       		local output = TestPreRelease.readOutput(git_branch)
       		-- print("debug: '" .. output .. "'")
       		is_equal(output, TestPreRelease.git_branch, "The git_branch tag in the publican.cfg file is correct. Got: " .. "\"" .. output .. "\"")
	else warn("The git_branch tag was not found in the publican.cfg file.")
	end
end

-- Check that there are no cvs_* labels in publican.cfg
function TestPreRelease.testCVSlabels()
	local CVS = "grep -e 'cvs_*' publican.cfg"
	local output = TestPreRelease.readOutput(CVS)
--	print ("debug: '" .. output .. "'")
	is_unlike(output, "cvs_*", "CVS labels are not present in publican.cfg.")
end

-- Check that there is no draft watermark
function TestPreRelease.testDraft()
	local draft = "xmlstarlet sel -t -v 'book/@status' "
	local command = draft .. TestPreRelease.rootfile .. " 2>/dev/null"
	local output = TestPreRelease.readOutput(command)
--	print("debug: '" .. output .. "'")
	is_unequal(output, "draft", "The draft watermark is not present.")
end

-- A warning is returned when the author group is 'Engineering Content Services'.
function TestPreRelease.testAuthorGroup()
	local group = "xmlstarlet sel -t -v '/authorgroup/author/affiliation/orgdiv' en-US/Author_Group.xml 2>/dev/null | sort -u"
	local output = TestPreRelease.readOutput(group)
--	print ("debug: '" .. output .. "'")
	if output ~= "Customer Content Services" then
		warn ("The team name is incorrect (it is supposed to be 'Customer Content Services'). Got: " .. "\"" .. output .. "\"")
	end
end

-- Check that there is no Preface.xml and Glossary.xml included in the root file of the book.
function TestPreRelease.testPreface()
	local preface = "xmlstarlet sel -N xi='http://www.w3.org/2001/XInclude' -t -v '//xi:include/@href' " .. TestPreRelease.rootfile .. " 2>/dev/null | grep -q Preface.xml;echo $?"
	local output = TestPreRelease.readOutput(preface)
--	print ("debug: '" .. output .. "'")
	is_equal(output, "1", "The Preface.xml file is not present.")
end

function TestPreRelease.testGlossary()
	local glossary = "xmlstarlet sel -N xi='http://www.w3.org/2001/XInclude' -t -v '//xi:include/@href' " .. TestPreRelease.rootfile .. " 2>/dev/null | grep -q Glossary.xml;echo $?"
	local output = TestPreRelease.readOutput(glossary)
--	print ("debug: '" .. output .. "'")
	is_equal(output, "1", "The Glossary.xml file is not present.")
end

-- Check that there is not the edition tag in the Book_Info.xml file
function TestPreRelease.testEdition()
	local edition = "xmlstarlet sel -t -v '//edition' en-US/Book_Info.xml 2>/dev/null" 
	local output = TestPreRelease.readOutput(edition)
--	print ("debug: '" .. output .. "'")
	is_equal(output, "", "The edition tag is not present in the Book_Info.xml file.")
end

-- Check that there is not the pubsnumber tag in the Book_Info.xml file 
function TestPreRelease.testPubsnumber()
	local pubsnumber = "xmlstarlet sel -t -v '//pubsnumber' en-US/Book_Info.xml 2>/dev/null"
	local output = TestPreRelease.readOutput(pubsnumber)
--	print ("debug: '" .. output .. "'")
	is_equal(output, "", "The pubsnumber tag is not present in the Book_Info.xml file")
end

-- Check that the first author group entry in Author_Group.xml has an email filled up.
function TestPreRelease.testAuthor()
	local author = "xmlstarlet sel -t -v '/authorgroup/author[1]' en-US/Author_Group.xml 2>/dev/null| grep -q @redhat.com;echo $?"
	local output = TestPreRelease.readOutput(author)
--	print ("debug: '" .. output .. "'")
	is_equal(output, "0", "The first author group entry has an email filled up.")
end

-- Check the first entry in the Revision_History.xml file.
-- TODO make it just to info - warn - How?
function TestPreRelease.testHistory()
	local history = "xmlstarlet sel -t -v '//member[1]' en-US/Revision_History.xml 2>/dev/null"
--	string.gsub(history, "%s+", "")
	local output = TestPreRelease.readOutput(history)
--	print ("debug: '" .. output .. "'")
	is_like(output, TestPreRelease.majorver .. "." .. TestPreRelease.minorver .. " " .. TestPreRelease.ga_beta, "The first entry in Revision history points to the correct release. Got: " .. "\"" .. output .. "\"")
end

--- GA release specific checks:

-- Check if there are any beta labels in the publican.cfg file.
function TestPreRelease.NoBeta()
	local beta = "grep -iq 'beta' publican.cfg;echo $?"
	local output = TestPreRelease.readOutput(beta)
--	print ("debug: '" .. output .. "'")
	is_equal(output, "1" , "There are no beta labels in the publican.cfg file.")
end

-- Check that there is no Beta disclaimer.
function TestPreRelease.NoDisclaimer()
	local disclaimer = "grep -q 'This document is under development' en-US/Book_Info.xml 2>/dev/null;echo $?"
	local output = TestPreRelease.readOutput(disclaimer)
--	print ("debug: '" .. output .. "'")
	is_equal(output, "1", "There is no Beta disclaimer.")
end

-- Check if the value of the productnumber tag is correct (for example 7).

function TestPreRelease.GAProductNumber()
	local product_number = "xmlstarlet sel -t -v 'bookinfo/productnumber' en-US/Book_Info.xml 2>/dev/null"
	local output = TestPreRelease.readOutput(product_number)
--	print ("debug: '" .. output .. "'")
	is_equal(output, TestPreRelease.majorver, "The product number in the Book_Info.xml file is correct. Got: " .. "\"" .. output .. "\"")
end
	
--- Beta release specific checks:

-- Check that there is the Beta disclaimer
function TestPreRelease.Disclaimer()
	local disclaimer = "grep -q 'This document is under development' en-US/Book_Info.xml 2>/dev/null;echo $?"
	local output = TestPreRelease.readOutput(disclaimer)
--	print ("debug: '" .. output .. "'")
	is_equal(output, "0", "There is the Beta disclaimer.")
end

-- Check that the version tag in publican.cfg is correct (for example: 7-Beta):
function TestPreRelease.BetaVersion()
	local version = "grep -e '^version' publican.cfg | sed 's/version:\\(.*\\)/\\1/'"
	local output = TestPreRelease.readOutput(version)
--	print ("debug: '" .. output .. "'")
	is_equal(output, TestPreRelease.majorver .. "-Beta", "The version tag in publican.cfg is correct. Got: " .. "\"" .. output "\"")
end

-- Check that the web_version_label tag in publican.cfg is correct (for example: "7.1 Beta"):
function TestPreRelease.WebVersion()
	local web_version = "grep  web_version_label publican.cfg | sed 's/web_version_label:\\(.*\\)/\\1/'"
	local output = TestPreRelease.readOutput(web_version)
--	print ("debug: '" .. output .. "'")
	is_equal(output, "\"" .. TestPreRelease.majorver .. "." .. TestPreRelease.minorver .. " Beta" .. "\"", "The web_version_label in publican.cfg is correct. Got: " .. "\"" .. output .. "\"")
end

-- Check that the value in the productnumber tag in Book_Info.xml is correct (for example 7.1 Beta)
function TestPreRelease.BetaProductNumber()
	local beta_product_number = "xmlstarlet sel -t -v 'bookinfo/productnumber' en-US/Book_Info.xml 2>/dev/null"
	local output = TestPreRelease.readOutput(beta_product_number)
--	print ("debug: '" .. output .. "'")
	is_equal(output, TestPreRelease.majorver .. "." .. TestPreRelease.minorver .. " Beta", "The product number in Book_Info.xml is correct. Got: " .. "\"" .. output .."\"")
end

function TestPreRelease.testRelease()
	-- make it "case insensitive"
	local upper = string.upper(TestPreRelease.ga_beta)
--	print(upper)
	if upper == "BETA" then
		TestPreRelease.Disclaimer()
		TestPreRelease.BetaVersion()
		TestPreRelease.WebVersion()
		TestPreRelease.BetaProductNumber()
	end
	if upper == "GA" then
		TestPreRelease.NoBeta()
		TestPreRelease.NoDisclaimer()
		TestPreRelease.GAProductNumber()
	end
end

--- Check that there is the sort_order tag in publican.cfg for RHEL 7 releases. 
function TestPreRelease.testSortOrder()
	if TestPreRelease.majorver == "7" then
		local sort_order = "grep -q sort_order publican.cfg;echo $?"
		local output = TestPreRelease.readOutput(sort_order)
		print ("debug: '" .. output .. "'")
		is_equal(output, "0", "There is the sort_order tag in publican.cfg")
	end
end



-- Check the correct version of the package - nice to have

----------------------------------------------------------------------------------

-- Test that Publican is able to build the book. - not needed

--function TestPreRelease.testBuild()
--	local pubsingle = "nice -n 15 publican build '--langs=en-US' '--formats=html-single' | grep 'Finished html-single'"
--	local output = TestPreRelease.readOutput(pubsingle)
--	output=string.trim(output)
--	print("debug: '" .. output .. "'")
--	is_equal(output, "Finished html-single", "Build was successful.")
--end


