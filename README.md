RPMBAAExt
=========

Resource automation and automation script extension for RPM and BLadeLogic integration. This extension provide automation to 
run job against targets that can be servers, servers group, components, components group.

Install
=======

On your BRPM installation in directory <BRPM install dir>/WEB-INF/lib/script_support, save/rename baa_utilities.rb.
On <BRPM install dir>/WEB-INF/lib/script_support/LIBRARY/automation/BMC Application Automation 8.2, save/rename baa_execute_job_against.rb.

Copy baa_utilities.rb to <BRPM install dir>/WEB-INF/lib/script_support
Files in automation directories need to be copied on BRPM server to:
  <BRPM install dir>/WEB-INF/lib/script_support/LIBRARY/automation/BMC Application Automation 8.2
Files resource_automation need to be copied on BRPM server to:
  <BRPM install dir>/WEB-INF/lib/script_support/LIBRARY/resource_automation/BMC Application Automation 8.2

Then you need to restart BRPM as baa_utilities.rb file has been changed.

Setup
=====

You need to create an integration server pointing to your BladeLogic server to point the API (if not already done):
  Server Name:  <up to you>
  Server URL:   <BladeLogic Webservice url; example: https://bl-appserver:9843>
  Username:     <BLadeLogic user>
  password:     <password of previously defined user>
  Details:		role: <role you want to use; example BLAdmins>
				authentication_mode: <example: SRP>
  
You need to import in automation (Environment -> Automation):
  1. The resource automation script that you associate with previously defined integration server:
      baa_job_gtargets.rb: provide multi selection three for targets allowing to select groups
      
  2. The automation scripts that you associate with previously defined integration server
      baa_execute_job_against.rb: execute an existing BladeLogic job to targets you specify, this using the resource baa_job_gtargets.rb
      

Improvments
===========
review all the automation that allows to selection targets for groups can be selected.
