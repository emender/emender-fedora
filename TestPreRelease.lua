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


-- NOTE: this test must be run in the directory with the publican.cfg file.

TestPreRelease = {
    metadata = {
        description = "Test if a book is ready for a GA or Beta release.",
        authors = "Barbora Ancincova",
        emails = "bancinco@redhat.com",
        changed = "2014-10-10",
        tags = {"Sanity", "XML"}
    },
    requires = {"publican","git","xmlstarlet","xmllint"},
    
    -- Change this according to the current release and book!: → no longer needed it can be specified with emend --X brand=RedHat)
    release = "6.6_GA",
    majorver = "6",
    minorver = "6",
    -- TODO make this automatic
    rootfile = "en-US/Deployment_Guide.xml",
    brand = "RedHat",
    git_branch = "docs-rhel-6"
}

-- Check the output of a command.

function TestPreRelease.readOutput(command)
	local fd = io.popen(command)
	local output = fd:read('*all')
	fd:close()
	output=string.trim(output)
	return output
end

-- Test if you are in the correct branch for example 7.0_GA, 7.1_Beta.
function TestPreRelease.testBranch()
	local git = "git rev-parse --abbrev-ref HEAD"
	local output = TestPreRelease.readOutput(git)
	print("debug: '" .. output .. "'")
	is_equal(output, TestPreRelease.release, "Branch is OK.")
end

-- Check that remarks are disabled.
function TestPreRelease.testRemarks()
	local remarks = "grep 'show_remarks: 0' publican.cfg"
	local output = TestPreRelease.readOutput(remarks)
	print("debug: '" .. output .. "'")
	is_equal(output, "show_remarks: 0", "Remarks are disabled.")
end

-- Check the correct brand
function TestPreRelease.testBrand()
	local brand = "grep brand publican.cfg | sed 's/brand:\\(.*\\)/\\1/'"
	local output = TestPreRelease.readOutput(brand)
	print("debug: '" .. output .. "'")
	is_equal(output, TestPreRelease.brand, "The brand is correct")
end

-- Check the correct git-branch in publican.cfg
function TestPreRelease.testGitBranch()
	local git_branch = "grep git_branch publican.cfg | sed 's/git_branch:\\(.*\\)/\\1/'"
	local output = TestPreRelease.readOutput(git_branch)
	print("debug: '" .. output .. "'")
	is_equal(output, TestPreRelease.git_branch, "Git-branch is correct.")
end

-- Check that there are no cvs_* labels in publican.cfg
function TestPreRelease.testCVSlabels()
	local CVS = "grep -e 'cvs_*' publican.cfg"
	local output = TestPreRelease.readOutput(CVS)
	print ("debug: '" .. output .. "'")
	is_unlike(output, "cvs_*", "CVS labels are not present.")
end

-- Check that there is no draft watermark
function TestPreRelease.testDraft()
	local draft = "xmlstarlet sel -t -v 'book/@status' "
	local command = draft .. TestPreRelease.rootfile .. " 2>/dev/null"
	local output = TestPreRelease.readOutput(command)
	print("debug: '" .. output .. "'")
	is_unequal(output, "draft", "Draft watermark is not present.")
end

-- A warning is returned when the author group is 'Engineering Content Services'.
function TestPreRelease.testAuthorGroup()
	local group = "xmlstarlet sel -t -v '/authorgroup/author/affiliation/orgdiv' en-US/Author_Group.xml | sort -u"
	local output = TestPreRelease.readOutput(group)
	print ("debug: '" .. output .. "'")
	if output ~= "Customer Content Services" then
		warn ("The team name is incorrect (it is supposed to be 'Customer Content Services').")
	end
end

-- Check that there is no Preface.xml and Glossary.xml included in the root file of the book.
-- TODO this could be probably done better with xmlstarlet (for example - the Preface.xml can be commented-out with <!-- -->..), Also, do we really want this test? And, it is not working anyway...
--function TestPreRelease.testPreface()
--	local grep = "grep 'Preface.xml'"
--	local command = grep .. TestPreRelease.rootfile .. " 2>/dev/null"
--	local output = TestPreRelease.testPreface(command)
--	print ("debug: '" .. output .. "'")
--	is_equal(output "", "The Preface.xml file is not present")
--end

-- TODO Check that there is no <edition> tag. (how to check tags with xmlstarlet?)
--function TestPreRelease.testEdition()
--	local = 
--end

-- TODO Check that there is no <pubsnumber> tag. 
--function TestPreRelease.testPubsnumber()
--	local = 
--end



-- GA release specific checks:

-- Check if there are any beta labels in the publican.cfg file.
function TestPreRelease.NoBeta()
	local beta = "grep -i beta publican.cfg"
	local output = TestPreRelease.readOutput(beta)
	print ("debug: '" .. output .. "'")
	is_equal(output, "" , "There are no beta labels in the publican.cfg file.")
end

-- Check that there is no Beta disclaimer.
function TestPreRelease.NoDisclaimer()
	-- TODO - Can I do it better with xmlstarlet? Is it needed?
	local disclaimer = "grep 'This document is under development, is subject to substantial change, and is provided only as a preview. The included information and instructions should not be considered complete, and should be used with caution.' en-US/Book_Info.xml"
	local output = TestPreRelease.readOutput(disclaimer)
	print ("debug: '" .. output .. "'")
	is_equal(output, "", "There is no Beta disclaimer.")
end

-- TODO Book_Info.xml: the productnumber tag in format: X

-- TODO web_version_label: "X.Y-Beta"

-- TODO the productnumber tag in format: X.Y-Beta

-- TODO Check the Revision History

function TestPreRelease.testBeta()
	local GA = string.find(TestPreRelease.release, "Beta")
	if GA then
		TestPreRelease.Disclaimer()
	end
end

-- TODO Check the Revision History

--TODO is is possible to make it case insensitive?
function TestPreRelease.testGA()
	local GA = string.find(TestPreRelease.release, "GA")
	if GA then
		TestPreRelease.NoBeta()
		TestPreRelease.NoDisclaimer()
	end
end




-- Beta release specific checks:

-- Check that there is the Beta disclaimer
function TestPreRelease.Disclaimer()
	-- TODO - Can I do it better with xmlstarlet? Is it needed?
	local disclaimer = "grep -o 'This document is under development, is subject to substantial change, and is provided only as a preview. The included information and instructions should not be considered complete, and should be used with caution.' en-US/Book_Info.xml"
	local output = TestPreRelease.readOutput(disclaimer)
	print ("debug: '" .. output .. "'")
	--TODO - Can I write it better? Like if return something (e.g. 0 exit status) then ... ?
	is_equal(output, "This document is under development, is subject to substantial change, and is provided only as a preview. The included information and instructions should not be considered complete, and should be used with caution.", "There is the Beta disclaimer.")
end

-- TODO version: X-Beta

-- TODO web_version_label: "X.Y-Beta"

-- TODO the productnumber tag in format: X.Y-Beta

-- TODO Check the Revision History

function TestPreRelease.testBeta()
	local Beta = string.find(TestPreRelease.release, "Beta")
	if Beta then
		TestPreRelease.Disclaimer()
	end
end


-- TODO Check the Revision History

-- Check the correct version of the package- nice to have




----------------------------------------------------------------------------------

-- Test that Publican is able to build the book. - not needed

--function TestPreRelease.testBuild()
--	local pubsingle = "nice -n 15 publican build '--langs=en-US' '--formats=html-single' | grep 'Finished html-single'"
--	local output = TestPreRelease.readOutput(pubsingle)
--	output=string.trim(output)
--	print("debug: '" .. output .. "'")
--	is_equal(output, "Finished html-single", "Build was successful.")
--end


