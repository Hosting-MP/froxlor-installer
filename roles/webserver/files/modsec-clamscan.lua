#!/usr/bin/lua
--[[
   This script can be used to inspect uploaded files for viruses
   via ClamAV. To implement, use with the following ModSecurity rule:

   SecRule FILES_TMPNAMES "@inspectFile /opt/modsecurity/bin/modsec-clamscan.lua" "phase:2,t:none,log,deny"

   Author: Angelo Conforti (based on Josh Amishav-Zlatin code)
   Requires the clamav-server and clamav-scanner
   
   If you use SELinux on RHEL base distro:
   setsebool -P antivirus_can_scan_system 1
   
   And remember that CentOS ClamAV distribution has some issue 
   with permission in the "default" configuration. Use Debian and
   you'll be happy :)

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--


function fsize(filename)
   file = io.open(filename,"r")
   local current = file:seek()
   local size = file:seek("end")
   file:seek("set",current)
   file:close()
   return size
end

function main(filename)
   -- Configure paths
   local clamdscan  = "/usr/bin/clamdscan"
   local clamscan  = "/usr/bin/clamscan"
   
   -- failoverOnClamdFailure: failover to clamscan if clamdscan report an error
   local failoverOnClamdFailure = true
   
   -- fail (and block) if clamdscan (and clamscan) fails
   local failOnError = false
   
   -- local var
   local agent = "clamdscan"

   -- Skip empty items because if clamd is not working and you
   -- use the clamscan agent an empty file can take about 12 secs 
   -- to be analyzed
   if fsize(filename) == 0 then
     m.log(1, "[scanav skipped, file " .. filename .." size is zero]")
     return nil
   end

   -- The system command we want to call with fdpass flag to 
   -- do not incur in a permission issue
   local cmd = clamdscan .. " --fdpass --stdout --no-summary"

   -- Run the command and get the output
   local f = io.popen(cmd .. " " .. filename .. " || true")
   local l = f:read("*a")
   f:close()

   -- Check the output for the FOUND or ERROR strings which indicate
   -- an issue we want to block access on
   local isVuln = string.find(l, "FOUND")
   local isError = string.find(l, "ERROR")

   -- If clamdscan fails and you want failover to the traditional clamscan...
   if isError and failoverOnClamdFailure then
     -- Try to use the clamscan program
     m.log(1, "[clamdscan fails (" .. l .. "), failover to clamscan]")
     agent = "clamscan"
     cmd = clamscan .. " --stdout --no-summary"
     f = io.popen(cmd .. " " .. filename .. " || true")
     l = f:read("*a")
     f:close()
     isVuln = string.find(l, "FOUND")
     isError = string.find(l, "ERROR")
   end

   if isVuln then
     m.log(1, "[" .. agent .. " scanner message: " .. l .. "]")
     return "Virus Detected"
   elseif isError and failOnError then
     -- is a error (not a virus) a failure event?
     m.log(1, "[" .. agent .. " scanner message: " .. l .. "]")
     return "Error Detected"
   else
     return nil
   end
end