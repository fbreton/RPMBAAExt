###
# Hypervisor:
#   name: hypervisor type
#   type: in-list-single
#   list_pairs: 1,Select|2,VMware|7,Solaris|10,XenServer|12,RHEV|14,HyperV
#   position: A1:B1
# Action:
#   name: action
#   type: in-list-single
#   list_pairs: 1,stop|2,start|3,delete
#   position: E1:F1
# VMs:
#   name: VM lisy
#   type: in-external-multi-select
#   external_resource: baa_list_vm
#   position: A2:F2
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

def get_list_vmid(vmselected,servers)
	listvmid = []
	vmselected.split(",").each do |elt|
		subelt = elt.split("|")
		if subelt[0] == "MapFromBRPMServers"
			vms = servers.split(",").collect { |x| x.strip } rescue []
			vms.each do |vm|
				vmid = BaaUtilities.get_value_from_uri(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE,"#{subelt[1]}#{vm}/AssetAttributeValues/Internal Attribute 1")
				vmid = ["#{subelt[2]} #{vmid}", "#{subelt[1]}#{vm}", vm]
				listvmid << vmid unless listvmid.include?(vmid)
			end
		else
		    vmid = [subelt[2], "#{subelt[1]}#{subelt[0]}", subelt[0]]
			listvmid << vmid unless listvmid.include?(vmid)
		end
	end
	return listvmid
end

session_id = BaaUtilities.baa_soap_login(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD)
raise "Could not login to BAA Cli Tunnel Service" if session_id.nil?
BaaUtilities.baa_soap_assume_role(BAA_BASE_URL, BAA_ROLE, session_id)

listvm = get_list_vmid(params["VMs"],params["servers"])

listvm.each do |vmid|
  vmstatus = BaaUtilities.get_value_from_uri(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE,"#{vmid[1]}/AssetAttributeValues/Power Status")
  case params["Action"]
	when "delete"
		BaaUtilities.baa_soap_execute_cli_command_by_param_list(BAA_BASE_URL, session_id, "Virtualization", "changeVirtualGuestPowerStatus", [vmid[0], "stop"]) if vmstatus == "Started"
		BaaUtilities.baa_soap_execute_cli_command_by_param_list(BAA_BASE_URL, session_id, "Virtualization", "deleteVirtualGuest", [vmid[0]])
	when "start"
		BaaUtilities.baa_soap_execute_cli_command_by_param_list(BAA_BASE_URL, session_id, "Virtualization", "changeVirtualGuestPowerStatus", [vmid[0], "start"]) if vmstatus == "Stopped"
	when "stop"
		BaaUtilities.baa_soap_execute_cli_command_by_param_list(BAA_BASE_URL, session_id, "Virtualization", "changeVirtualGuestPowerStatus", [vmid[0], "stop"]) if vmstatus == "Started"
  end
end


