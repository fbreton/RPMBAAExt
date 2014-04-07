###
# Hypervisor:
#   name: hypervisor type
#   type: in-list-single
#   list_pairs: 1,Select|2,VMware|7,Solaris|10,XenServer|12,RHEV|14,HyperV
#   position: A1:B1
# VMTemplate:
#   name: vmtemplate
#   type: in-external-single-select
#   external_resource: baa_vgp
#   position: A2:D2
# Location:
#   name: location
#   type: in-external-single-select
#   external_resource: baa_vgp_target
#   position: A3:F3
# IPResolution:
#   name: ip resolution methode
#   type: in-list-single
#   list_pairs: 1,File|2,DNS
#   position: A4:B4
# DHCP:
#   name: using or not DHCP
#   type: in-list-single
#   list_pairs: 1,No|2,Yes
#   position: E4:F4
# IPaddress:
#   name: ip address
#   position: A5:B5
# SubnetMask:
#   name: netmask
#   position: E5:F5
# Gateway:
#   name: default gateway
#   position: A6:B6
# HostName:
#   name: host name
#   position: E6:F6
# DNS:
#   name: primary DNS
#   position: A7:B7
# Domain:
#   name: domain name
#   position: E7:F7
###

require 'json'
require 'rest-client'
require 'uri'
require 'savon'
require 'base64'
require 'yaml'
require 'lib/script_support/baa_utilities'

params["direct_execute"] = true

baa_config = YAML.load(SS_integration_details)

BAA_USERNAME = SS_integration_username
BAA_PASSWORD = decrypt_string_with_prefix(SS_integration_password_enc)
BAA_ROLE = baa_config["role"]
BAA_BASE_URL = SS_integration_dns

UPDATE_PROPS_JOB = "/BRPM/Provisioning/Update properties"
UPDATE_IPRES_JOB = "/BRPM/Provisioning/Update IP resolution"

session_id = BaaUtilities.baa_soap_login(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD)
raise "Could not login to BAA Cli Tunnel Service" if session_id.nil?
BaaUtilities.baa_soap_assume_role(BAA_BASE_URL, BAA_ROLE, session_id)

# Check that we've the needed data
hostname = sub_tokens(params, params["HostName"])
ipaddress = sub_tokens(params, params["IPaddress"])
subnetmask = sub_tokens(params, params["SubnetMask"])
gateway = sub_tokens(params, params["Gateway"])
dns = sub_tokens(params, params["DNS"])
domain = sub_tokens(params, params["Domain"])

raise "Error: You need to select an Hypervisor" if params["Hypervisor"] == "Select"
raise "Error: You need to select a target location" if params["Location"].empty?
raise "Error: You need to provide a host name" if hostname.empty?
raise "Error: You need to complete IPadresse and Subnet Mask when DHCP iset to No" if params["DHCP"] == "No" && ( ipaddress.empty? || subnetmask.empty?)

# Initialize variables
vgpgroup = "/BRPM/Provisioning"
jobgroup = "/BRPM/Provisioning"
jobgroupid = BaaUtilities.baa_soap_execute_cli_command_by_param_list(BAA_BASE_URL, session_id,"JobGroup", "groupNameToId", [jobgroup])[:return_value]
vgpname = params["VMTemplate"].split("|")[0]
jobname = hostname + "-" + vgpname + "-" + Time.now.strftime("%Y%m%d-%H:%M:%S")
datastore = params["Location"].split("|")[0]
vgpdest = params["Location"].split("|")[2]
vgpid = BaaUtilities.baa_soap_execute_cli_command_by_param_list(BAA_BASE_URL, session_id, "Virtualization", "getVirtualGuestPackageIdByGroupAndName", [vgpgroup,vgpname])[:return_value]
vgpdef = BaaUtilities.baa_soap_execute_cli_command_by_param_list(BAA_BASE_URL, session_id, "Virtualization", "getVirtualGuestPackage", [vgpid])[:return_value]
vgpid = BaaUtilities.baa_soap_execute_cli_command_by_param_list(BAA_BASE_URL, session_id, "Virtualization", "getVirtualGuestPackageIdByGroupAndName", [vgpgroup,vgpname])[:return_value]

########################################################################
###building xml definition of the virtual guest package provisioning job
########################################################################
vgpjdef = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<VirtualGuestJobConfiguration>
    <VirtualGuestPackage>
        <VGPackageID>#{vgpid}</VGPackageID>
        <VirtualGuestName>#{hostname}</VirtualGuestName>
" + vgpdef[/<PlatformInfo>.*PlatformInfo>/m] + "
    </VirtualGuestPackage>
    <VirtualGuestJob>
	<JobName>#{jobname}</JobName>
	<JobFolderID>#{jobgroupid}</JobFolderID>
        <VirtualGuestDestination>#{vgpdest}</VirtualGuestDestination>
        <ExecuteNow>false</ExecuteNow>
    </VirtualGuestJob>
</VirtualGuestJobConfiguration>
"
# Putting datastore location
vgpjdef = vgpjdef.gsub(/<Datastore>[^<]*/m, "<Datastore>#{datastore}")
vgpjdef = vgpjdef.gsub(/<VMXDatastore>[^<]*/m, "<VMXDatastore>#{datastore}")

# Setting the right network parameters
if params["DHCP"] == "Yes"
	networkdef = "<GuestNetworkConfiguration>
				<AutoIPAddress>true</AutoIPAddress>
				<AutoDNS>true</AutoDNS>
			</GuestNetworkConfiguration>"
else
	networkdef = "<GuestNetworkConfiguration>
				<IPAddress>#{ipaddress}</IPAddress>
				<SubnetMask>#{subnetmask}</SubnetMask>
				<DefaultGateway>#{gateway}</DefaultGateway>
				<PrimaryDNS>#{dns}</PrimaryDNS>
			</GuestNetworkConfiguration>"
end
vgpjdef = vgpjdef.gsub(/<GuestNetworkConfiguration>.*<\/GuestNetworkConfiguration>/m, networkdef)

# Setting hostname and domaine
vgpjdef = vgpjdef.gsub(/<HostName>[^<]*/m, "<HostName>#{hostname}")
vgpjdef = vgpjdef.gsub(/<Domain>[^<]/m, "<Domain>#{domain}")

########################################################################
###Create virtual guest package job and run it
########################################################################
qualfname = params["SS_base_url"].split(":")[1] + "/notneeded"
jobdbkey = BaaUtilities.baa_soap_execute_cli_command_using_attachments(BAA_BASE_URL, session_id, "Virtualization", "createVirtualGuest", [qualfname], vgpjdef)[:return_value].split(" ").last
joburi = BaaUtilities.baa_soap_db_key_to_rest_uri(BAA_BASE_URL, session_id, jobdbkey)
h = BaaUtilities.execute_job(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE, joburi)
raise "Could run specified job, did not get a valid response from server" if h.nil?

# Manage Job result output
execution_status = "OK"
execution_status = "VM provisioning error" if (h["had_errors"] == "true")

########################################################################
###Run IP resolution update Job if exist
########################################################################
jobdbkey = BaaUtilities.get_job_dbkey_from_job_qualified_name(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE, UPDATE_IPRES_JOB) rescue nil
if (execution_status == "OK") && (jobdbkey != nil) && (ipaddress != "")
	job_group = File.dirname(UPDATE_IPRES_JOB)
	job_name = hostname + "-UpdateIPresolution-" + Time.now.strftime("%Y%m%d-%H:%M:%S")
	session_id = BaaUtilities.baa_soap_login(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD)
	raise "Could not login to BAA Cli Tunnel Service" if session_id.nil?
	BaaUtilities.baa_soap_assume_role(BAA_BASE_URL, BAA_ROLE, session_id)
	jobdbkey = BaaUtilities.baa_soap_execute_cli_command_by_param_list(BAA_BASE_URL, session_id,"Job","copyJob",[jobdbkey,job_group,job_name])[:return_value]
	jobdbkey = BaaUtilities.baa_set_nsh_script_property_value_in_job(BAA_BASE_URL, session_id, job_group, job_name, 0, params["IPResolution"])
	jobdbkey = BaaUtilities.baa_set_nsh_script_property_value_in_job(BAA_BASE_URL, session_id, job_group, job_name, 1, ipaddress)
	jobdbkey = BaaUtilities.baa_set_nsh_script_property_value_in_job(BAA_BASE_URL, session_id, job_group, job_name, 2, hostname)
	joburi = BaaUtilities.get_job_uri_from_job_qualified_name(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE, "#{job_group}/#{job_name}")
	h1 = BaaUtilities.execute_job(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE, joburi)
	execution_status = "Update IP Resolution error" if (h1["had_errors"] == "true")
end

########################################################################
###Run Update properties Job if exist
########################################################################
jobdbkey = BaaUtilities.get_job_dbkey_from_job_qualified_name(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE, UPDATE_PROPS_JOB) rescue nil
if (execution_status == "OK") && (jobdbkey != nil)
	job_group = File.dirname(UPDATE_PROPS_JOB)
	job_name = hostname + "-UpdateProperties-" + Time.now.strftime("%Y%m%d-%H:%M:%S")
	jobdbkey = BaaUtilities.baa_soap_execute_cli_command_by_param_list(BAA_BASE_URL, session_id,"Job","copyJob",[jobdbkey,job_group,job_name])[:return_value]
	joburi = BaaUtilities.get_job_uri_from_job_qualified_name(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE, "#{job_group}/#{job_name}")
	servuri = BaaUtilities.get_server_uri_from_name(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE,hostname)
	agtstatus = "down"
	nbtry = 0
	until (nbtry > 16) || (agtstatus == "agent is alive") do
		sleep(15)
		h1 = BaaUtilities.execute_job_against_servers(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE, joburi, [servuri])
		agtstatus = BaaUtilities.get_property_value_from_uri(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE, servuri, "AGENT_STATUS")
		nbtry += 1
	end
	raise "Can not reach BladeLogic Agent" if nbtry > 16
	execution_status = "Update props error" if (h1["had_errors"] == "true")
end

# Add Server to environment if the job is successful
if (execution_status == "OK") 
  servers = "name, environment\n"
  servers += "#{hostname}, #{params["SS_environment"]}\n"
  set_server_flag(servers)
  write_to("Server #{hostname} has been well provisioned")
else
  write_to("Error: #{execution_status}")
end 



