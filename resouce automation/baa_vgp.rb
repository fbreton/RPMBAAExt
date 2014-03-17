###
# Hypervisor:
#   name: hypervisor type
#   type: in-list-single
#   list_pairs: 2,VMware|7,Solaris|10,XenServer|12,RHEV|14,HyperV
###

require 'json'
require 'rest-client'
require 'uri'
require 'yaml'
require 'script_support/baa_utilities'

baa_config = YAML.load(SS_integration_details)

BAA_USERNAME = SS_integration_username
BAA_PASSWORD = decrypt_string_with_prefix(SS_integration_password_enc)
BAA_ROLE = baa_config["role"]
BAA_BASE_URL = SS_integration_dns

def getVGPTypeId(typename)
	case typename
		when "VMware"
			return "2"
		when "Solaris"
			return "7"
		when "XenServer"
			return "10"
		when "RHEV"
			return "12"
		when "HyperV"
			return "14"
	end
end

def execute(script_params, parent_id, offset, max_records)

    url = "#{BAA_BASE_URL}/group/Depot/BRPM/Provisioning"
    url += "?username=#{BAA_USERNAME}&password=#{BAA_PASSWORD}&role=#{BAA_ROLE}"
    response = RestClient.get URI.escape(url), :accept => :json 
    parsed_response = JSON.parse(response)
    group = parsed_response["GroupResponse"]["Group"] rescue nil
	vgplist = BaaUtilities.get_child_objects_from_parent_group(BAA_BASE_URL, BAA_USERNAME, BAA_PASSWORD, BAA_ROLE, group["modelType"], group["objectId"], "VIRTUAL_GUEST_PACKAGE")
	data = [{"Select" => ""}]
	if vgplist
		vgplist.each do |vgp|
			url = "#{BAA_BASE_URL}#{vgp["uri"]}?username=#{BAA_USERNAME}&password=#{BAA_PASSWORD}&role=#{BAA_ROLE}"
			response = RestClient.get URI.escape(url), :accept => :json
			parsed_response = JSON.parse(response)
			propslist = parsed_response["PropertySetInstanceResponse"]["PropertySetInstance"]["PropertyValues"]["Elements"]
			vgptypeid = ""
			propslist.each do |props|
				if props["name"] == "VGP_TYPE_ID*"
					vgptypeid = props["value"]
					break
				end
			end
			data << {vgp["name"] => "#{vgp["name"]}|#{vgp["dbKey"]}"} if vgptypeid == getVGPTypeId(script_params["Hypervisor"])
		end
	end
	data << {"No template for #{script_params["Hypervisor"]}" => ""} if data.empty?
    return data
end

def import_script_parameters
  { "render_as" => "List" }
end