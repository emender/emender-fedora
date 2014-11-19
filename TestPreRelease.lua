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

TestPreRelease = {
    metadata = {
        description = "Test if a book is ready for a GA or Beta release.",
        authors = "Barbora Ancincova",
        emails = "bancinco@redhat.com",
        changed = "2014-10-10",
        tags = {"Sanity", "XML"}
    },
    requires = {"publican","git","xmlstarlet","xmlstarlet","xmllint"},
    -- Change this according to the current release and book!:
    release = "6.6_GA",
    majorver = "6",
    minorver = "6",
    rootfile = "en-US/Deployment_Guide.xml"
}

-- Check the output of a command.

function TestPreRelease.readOutput(command)
	local fd = io.popen(command)
	local output = fd:read('*all')
	fd:close()
	return output
end

-- Test if you are in the correct branch for example 7.0_GA, 7.1_Beta.

function TestPreRelease.testBranch()
	local git = "git rev-parse --abbrev-ref HEAD"
	local output = TestPreRelease.readOutput(git)
	output=string.trim(output)
	print("debug: '" .. output .. "'")
	is_equal(output, TestPreRelease.release, "Branch is OK.")
end

-- Test that Publican is able to build the book.

function TestPreRelease.testBuild()
	local pubsingle = "nice -n 15 publican build '--langs=en-US' '--formats=html-single' | grep 'Finished html-single'"
	local output = TestPreRelease.readOutput(pubsingle)
	output=string.trim(output)
	print("debug: '" .. output .. "'")
	is_equal(output, "Finished html-single", "Build was successful.")
end

-- Check that remarks are disabled.

function TestPreRelease.testRemarks()
	local remarks = "grep 'show_remarks: 0' publican.cfg"
	local output = TestPreRelease.readOutput(remarks)
	output=string.trim(output)
	print("debug: '" .. output .. "'")
	is_equal(output, "show_remarks: 0", "Remarks are disabled.")
end

-- Check that there is no draft watermark

function TestPreRelease.testDraft()
	local draft = "xmlstarlet sel -t -v 'book/@status' "
	local command = draft .. TestPreRelease.rootfile .. " 2>/dev/null"
	local output = TestPreRelease.readOutput(command)
	output=string.trim(output)
	print("debug: '" .. output .. "'")
	is_unequal(output, "draft", "Draft watermark is not present.")
end

-- For Beta release only: check there is the disclaimer
	-- TODO write something like if there is "beta" specified in variable release, run this test, otherwise don't


-- Check the Revision History

-- Check the correct version



