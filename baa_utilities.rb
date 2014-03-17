require 'json'
require 'rest-client'
require 'uri'
require 'savon'
require 'base64'

module BaaUtilities
  class << self
  
    def rest_version
      "8.2"
    end

    def get_type_url(execute_against)
      case execute_against
      when "servers"
        return "/type/PropertySetClasses/SystemObject/Server"
      when "components"
        return "/type/PropertySetClasses/SystemObject/Component"
      when "staticServerGroups", "staticComponentGroups"
        return "/type/PropertySetClasses/SystemObject/Static Group"
      when "smartServerGroups", "smartComponentGroups"
        return "/type/PropertySetClasses/SystemObject/Smart Group"
      end
    end

    def get_execute_against_operation(execute_against)
      case execute_against
      when "servers"
        return "executeAgainstServers"
      when "components"
        return "executeAgainstComponents"
      when "staticServerGroups"
        return "executeAgainstStaticServerGroups"
      when "staticComponentGroups"
        return "executeAgainstStaticComponentGroups"
      when "smartServerGroups"
        return "executeAgainstSmartServerGroups"
      when "smartComponentGroups"
        return "executeAgainstSmartComponentGroups"
      end
    end

    def execute_job_internal(baa_base_url, baa_username, baa_password, baa_role, job_url, operation, arguments_hash)
      url = "#{baa_base_url}#{job_url}/Operations/#{operation}"
      url += "?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"

      response = RestClient.post URI.escape(url), arguments_hash.to_json, :content_type => :json, :accept => :json
      response = JSON.parse(response)
      if response.has_key? "ErrorResponse"
        raise "Error while posting to URL #{url}: #{response["ErrorResponse"]["Error"]}"
      end
 
      query_url = ""
      if response && response["OperationResultResponse"] && 
        response["OperationResultResponse"]["OperationResult"] && response["OperationResultResponse"]["OperationResult"]["value"]
        query_url = response["OperationResultResponse"]["OperationResult"]["value"]

        delay = 0
        begin
          sleep(delay)
          url = "#{baa_base_url}#{query_url}?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"
          response = RestClient.get URI.escape(url), :accept => :json
          response = JSON.parse(response)

          if response.has_key? "ErrorResponse"
            raise "Error while querying URL #{url}: #{response["ErrorResponse"]["Error"]}"
          end

          delay = 10
        end while (response.empty? || response["StatusResponse"].empty? || (response["StatusResponse"]["Status"]["status"] == "RUNNING"))

        h = {}
        h["status"] = response["StatusResponse"]["Status"]["status"] 
        h["had_errors"] = response["StatusResponse"]["Status"]["hadErrors"]
        h["had_warnings"] = response["StatusResponse"]["Status"]["hadWarnings"]
        h["is_aborted"] = response["StatusResponse"]["Status"]["isAbort"]
        h["job_run_url"] = response["StatusResponse"]["Status"]["targetURI"]
        return h
      end
      return nil
    end
	
    def execute_job_against_internal(baa_base_url, baa_username, baa_password, baa_role, job_url, targets, execute_against)
      h = {}
      h["OperationArguments"] = []
      h["OperationArguments"].push({})
      h["OperationArguments"][0]["name"] = execute_against
      h["OperationArguments"][0]["type"] = get_type_url(execute_against)
      h["OperationArguments"][0]["uris"] = []
        
      targets.each do |t|
        h["OperationArguments"][0]["uris"].push(t)
      end

      operation = get_execute_against_operation(execute_against)
      return execute_job_internal(baa_base_url, baa_username, baa_password, baa_role, job_url, operation, h)
    end
    
    def execute_job_against_servers(baa_base_url, baa_username, baa_password, baa_role, job_url, targets)
      return execute_job_against_internal(baa_base_url, baa_username, baa_password, baa_role, job_url, targets, "servers")
    end

    def execute_job_against_static_server_groups(baa_base_url, baa_username, baa_password, baa_role, job_url, targets)
      return execute_job_against_internal(baa_base_url, baa_username, baa_password, baa_role, job_url, targets, "staticServerGroups")
    end

    def execute_job_against_smart_server_groups(baa_base_url, baa_username, baa_password, baa_role, job_url, targets)
      return execute_job_against_internal(baa_base_url, baa_username, baa_password, baa_role, job_url, targets, "smartServerGroups")
    end

    def execute_job_against_components(baa_base_url, baa_username, baa_password, baa_role, job_url, targets)
      return execute_job_against_internal(baa_base_url, baa_username, baa_password, baa_role, job_url, targets, "components")
    end

    def execute_job_against_static_component_groups(baa_base_url, baa_username, baa_password, baa_role, job_url, targets)
      return execute_job_against_internal(baa_base_url, baa_username, baa_password, baa_role, job_url, targets, "staticComponentGroups")
    end

    def execute_job_against_smart_component_groups(baa_base_url, baa_username, baa_password, baa_role, job_url, targets)
      return execute_job_against_internal(baa_base_url, baa_username, baa_password, baa_role, job_url, targets, "smartComponentGroups")
    end


    def execute_job(baa_base_url, baa_username, baa_password, baa_role, job_url)
      return execute_job_internal(baa_base_url, baa_username, baa_password, baa_role, job_url, "execute", {})
    end

    def get_id_from_db_key(db_key)
      last_component = db_key.split(":").last
      if last_component
        return last_component.split("-")[0].to_i
      end
      return nil
    end

    def get_job_run_db_key(baa_base_url, baa_username, baa_password, baa_role, job_run_url)
      url = "#{baa_base_url}#{job_run_url}?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"
      response = RestClient.get URI.escape(url), :accept => :json

      response = JSON.parse(response)
      if response.has_key? "ErrorResponse"
        raise "Error while posting to URL #{url}: #{response["ErrorResponse"]["Error"]}"
      end

      if response["PropertySetInstanceResponse"] && response["PropertySetInstanceResponse"]["PropertySetInstance"]
        return response["PropertySetInstanceResponse"]["PropertySetInstance"]["dbKey"]
      end

      return nil
    end

    def get_job_run_id(baa_base_url, baa_username, baa_password, baa_role, job_run_url)
      db_key = get_job_run_db_key(baa_base_url, baa_username, baa_password, baa_role, job_run_url)
      return get_id_from_db_key(db_key) unless db_key.nil?
      return nil
    end


    def get_object_property_value(baa_base_url, baa_username, baa_password, baa_role, object_url, property, bquery = "")
      url = "#{baa_base_url}#{object_url}/PropertyValues/#{property}/?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"
      url += bquery
      response = RestClient.get URI.escape(url), :accept => :json
      response = JSON.parse(response)
    
      if response.has_key? "ErrorResponse"
        raise "Error while querying URL #{url}: #{response["ErrorResponse"]["Error"]}"
      end

      if response["PropertyValueChildrenResponse"] && response["PropertyValueChildrenResponse"]["PropertyValueChildren"] &&
        response["PropertyValueChildrenResponse"]["PropertyValueChildren"]["PropertyValueElements"]
        return response["PropertyValueChildrenResponse"]["PropertyValueChildren"]["PropertyValueElements"]["Elements"]
      end
      nil
    end

    def get_job_result_url(baa_base_url, baa_username, baa_password, baa_role, job_run_url)
      elements = get_object_property_value(baa_base_url, baa_username, baa_password, baa_role, job_run_url, "JOB_RESULTS*")
      element = elements[0] if elements
      results_psi = element["PropertySetInstance"] if element
      return results_psi["uri"] if results_psi
      nil
    end

    def get_per_target_results_internal(baa_base_url, baa_username, baa_password, baa_role, job_result_url, property, clazz)
      bquery = "&bquery=select name, had_errors, had_warnings, requires_reboot, exit_code* from \"SystemObject/#{clazz}\""

      h = {}
      elements = get_object_property_value(baa_base_url, baa_username, baa_password, baa_role, job_result_url, property, bquery)
      if elements
        elements.each do |jrd|
          if jrd["PropertySetInstance"]
            target = jrd["PropertySetInstance"]["name"]
            properties = {}
            if jrd["PropertySetInstance"]["PropertyValues"]
              values = jrd["PropertySetInstance"]["PropertyValues"]["Elements"]
              if values
                values.each do |val|
                  properties[val["name"]] = val["value"]
                end
              end
            end
            h[target] = properties
          end
        end
      end
      return h
    end

    def get_per_target_server_results(baa_base_url, baa_username, baa_password, baa_role, job_result_url)
      return get_per_target_results_internal(baa_base_url, baa_username, baa_password, baa_role, job_result_url, "JOB_RESULT_DEVICES*", "Job Result Device")
    end

    def get_per_target_component_results(baa_base_url, baa_username, baa_password, baa_role, job_result_url)
      return get_per_target_results_internal(baa_base_url, baa_username, baa_password, baa_role, job_result_url, "JOB_RESULT_COMPONENTS*", "Job Result Component")
    end

    def get_per_target_results(baa_base_url, baa_username, baa_password, baa_role, job_result_url)
      h = {}
      h["Server"] = get_per_target_server_results(baa_base_url, baa_username, baa_password, baa_role, job_result_url)
      h["Component"] = get_per_target_component_results(baa_base_url, baa_username, baa_password, baa_role, job_result_url)
      h
    end

    ###################################################################################
    #
    # Gets a list of components for specified component template
    #
    ###################################################################################
    def get_components_for_component_template(baa_base_url, baa_username, baa_password, baa_role, component_template_id)
      component_template_url = "/id/#{get_model_type_to_psc_name("TEMPLATE")}/#{component_template_id}"
      return get_object_property_value(baa_base_url, baa_username, baa_password, baa_role, component_template_url, "COMPONENTS*").collect {|item| item["PropertySetInstance"]}
    end

    def get_model_type_to_psc_name(model_type)
      case model_type
	  when "VIRTUAL_GUEST_PACKAGE"
		return "SystemObject/Depot Object/Virtual Guest Package"
      when "JOB_GROUP"
        return "SystemObject/Static Group/Job Group"
      when "DEPOT_GROUP"
        return "SystemObject/Static Group/Abstract Depot Group/Depot Group"
      when "STATIC_SERVER_GROUP"
        return "SystemObject/Static Group/Static Server Group"
      when "STATIC_COMPONENT_GROUP"
        return "SystemObject/Static Group/Static Component Group"
      when "TEMPLATE_GROUP"
        return "SystemObject/Static Group/Template Group"
      when "SMART_JOB_GROUP", "SMART_SERVER_GROUP", "SMART_DEVICE_GROUP", "SMART_COMPONENT_GROUP", "SMART_DEPOT_GROUP", "SMART_TEMPLATE_GROUP"
        return "SystemObject/Smart Group"
      when "SERVER"
        return "SystemObject/Server"
      when "COMPONENT"
        return "SystemObject/Component"
	  when "ALL_DEPOT_OBJECT"
	    return "SystemObject/Depot Object"
      when "BLPACKAGE"
        return "SystemObject/Depot Object/BLPackage"
      when "NSHSCRIPT"
        return "SystemObject/Depot Object/NSH Script"
      when "AIX_PATCH_INSTALLABLE"
        return "SystemObject/Depot Object/Software/AIX Patch"
      when "AIX_PACKAGE_INSTALLABLE"
        return "SystemObject/Depot Object/Software/AIX Package"
      when "HP_PRODUCT_INSTALLABLE"
        return "SystemObject/Depot Object/Software/HP-UX Product"
      when "HP_BUNDLE_INSTALLABLE"
        return "SystemObject/Depot Object/Software/HP-UX Bundle"
      when "HP_PATCH_INSTALLABLE"
        return "SystemObject/Depot Object/Software/HP-UX Patch"
      when "RPM_INSTALLABLE"
        return "SystemObject/Depot Object/Software/RPM"
      when "SOLARIS_PATCH_INSTALLABLE"
        return "SystemObject/Depot Object/Software/Solaris Patch"
      when "SOLARIS_PACKAGE_INSTALLABLE"
        return "SystemObject/Depot Object/Software/Solaris Package"
      when "HOTFIX_WINDOWS_INSTALLABLE"
        return "SystemObject/Depot Object/Software/Win Depot Software/Hotfix"
      when "SERVICEPACK_WINDOWS_INSTALLABLE"
        return "SystemObject/Depot Object/Software/Win Depot Software/OS Service Pack"
      when "MSI_WINDOWS_INSTALLABLE"
        return "SystemObject/Depot Object/Software/Win Depot Software/MSI Package"
      when "INSTALLSHIELD_WINDOWS_INSTALLABLE"
        return "SystemObject/Depot Object/Software/Win Depot Software/InstallShield Package"
      when "FILE_DEPLOY_JOB"
        return "SystemObject/Job/File Deploy Job"
      when "DEPLOY_JOB"
        return "SystemObject/Job/Deploy Job"
      when "NSH_SCRIPT_JOB"
        return "SystemObject/Job/NSH Script Job"
      when "SNAPSHOT_JOB"
        return "SystemObject/Job/Snapshot Job"
      when "COMPLIANCE_JOB"
        return "SystemObject/Job/Compliance Job"
      when "AUDIT_JOB"
        return "SystemObject/Job/Audit Job"
      when "TEMPLATE"
        return "SystemObject/Component Template"
      end
    end

    def get_model_type_to_model_type_id(model_type)
      case model_type
      when "JOB_GROUP"
        return 5005
      when "SMART_JOB_GROUP"
        return 5006
      when "STATIC_SERVER_GROUP"
        return 5003
      when "SMART_SERVER_GROUP"
        return 5007
      when "DEPOT_GROUP"
        return 5001
      when "SMART_DEPOT_GROUP"
        return 5012
      when "TEMPLATE_GROUP"
        return 5008
      when "SMART_TEMPLATE_GROUP"
        return 5016
      when "STATIC_COMPONENT_GROUP"
        return 5014
      when "SMART_COMPONENT_GROUP"
        return 5015
      end
    end

    def is_a_group(model_type)
      case model_type
      when "JOB_GROUP", "DEPOT_GROUP", "STATIC_COMPONENT_GROUP", "STATIC_SERVER_GROUP", "TEMPLATE_GROUP", "DEVICE_GROUP",
            "SMART_SERVER_GROUP", "SMART_DEVICE_GROUP", "SMART_JOB_GROUP", "SMART_COMPONENT_GROUP", "SMART_DEPOT_GROUP"
        return true
      end
      return false
    end

    
    def get_child_objects_from_parent_group(baa_base_url, baa_username, baa_password, baa_role, parent_object_type, parent_id, child_object_type)
      url = "#{baa_base_url}/id/#{get_model_type_to_psc_name(parent_object_type)}/#{parent_id}/"
      url += "?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"
      url += "&bquery=select name from \"#{get_model_type_to_psc_name(child_object_type)}\""
      response = RestClient.get URI.escape(url), :accept => :json 
      parsed_response = JSON.parse(response)

      if parsed_response.has_key? "ErrorResponse"
        raise "Error while query URL #{url}: #{parsed_response["ErrorResponse"]["Error"]}"
      end
  
      if is_a_group(child_object_type)
        objects = parsed_response["GroupChildrenResponse"]["GroupChildren"]["Groups"]
      else
        objects = parsed_response["GroupChildrenResponse"]["GroupChildren"]["PropertySetInstances"]
      end
      return objects["Elements"] if objects
      nil
    end


    def get_root_group_name(object_type)
      case object_type
      when "JOB_GROUP"
        return "Jobs"
      when "DEPOT_GROUP"
        return "Depot"
      when "STATIC_SERVER_GROUP"
        return "Servers"
      when "STATIC_COMPONENT_GROUP"
        return "Components"
      when "TEMPLATE_GROUP"
        return "Component Templates"
      end
    end


	def get_job_uri_from_job_qualified_name(baa_base_url, baa_username, baa_password, baa_role, job)
      url = "#{baa_base_url}/group/Jobs#{job}"
      url += "?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"

      response = RestClient.get URI.escape(url), :accept => :json 
      parsed_response = JSON.parse(response)

      if parsed_response.has_key? "ErrorResponse"
        raise "Error while query URL #{url}: #{parsed_response["ErrorResponse"]["Error"]}"
      end
  
      return parsed_response["PropertySetInstanceResponse"]["PropertySetInstance"]["uri"] rescue nil
	end

	def get_job_dbkey_from_job_qualified_name(baa_base_url, baa_username, baa_password, baa_role, job)
      url = "#{baa_base_url}/group/Jobs#{job}"
      url += "?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"

      response = RestClient.get URI.escape(url), :accept => :json 
      parsed_response = JSON.parse(response)

      if parsed_response.has_key? "ErrorResponse"
        raise "Error while query URL #{url}: #{parsed_response["ErrorResponse"]["Error"]}"
      end
  
      return parsed_response["PropertySetInstanceResponse"]["PropertySetInstance"]["dbKey"] rescue nil
	end
	
    def get_root_group(baa_base_url, baa_username, baa_password, baa_role, object_type)
      url = "#{baa_base_url}/group/#{get_root_group_name(object_type)}"
      url += "?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"

      response = RestClient.get URI.escape(url), :accept => :json 
      parsed_response = JSON.parse(response)

      if parsed_response.has_key? "ErrorResponse"
        raise "Error while query URL #{url}: #{parsed_response["ErrorResponse"]["Error"]}"
      end
  
      return parsed_response["GroupResponse"]["Group"] rescue nil
    end

    def find_job_from_job_folder(baa_base_url, baa_username, baa_password, baa_role, job_name, job_model_type, job_group_rest_id)
      url = "#{baa_base_url}/id/#{get_model_type_to_psc_name(job_model_type)}/#{job_group_rest_id}/"
      url += "?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"
      url += "&bquery=select name from \"SystemObject/Job\" "
      url += " where name = \"#{job_name}\""

      response = RestClient.get URI.escape(url), :accept => :json 
      parsed_response = JSON.parse(response)

      if parsed_response.has_key? "ErrorResponse"
        raise "Error while query URL #{url}: #{parsed_response["ErrorResponse"]["Error"]}"
      end

      unless parsed_response["GroupChildrenResponse"]["GroupChildren"].has_key? "PropertySetInstances"
        raise "Could not find job #{job_name} inside selected job folder."
      end

      job_obj = parsed_response["GroupChildrenResponse"]["GroupChildren"]["PropertySetInstances"]["Elements"][0] rescue nil
      return job_obj
    end
	
	def get_assets_from_uri(baa_base_url, baa_username, baa_password, baa_role,uri)
		url = "#{baa_base_url}#{uri}?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}"
		response = RestClient.get URI.escape(url), :accept => :json 
		parsed_response = JSON.parse(response)
		if parsed_response.has_key? "ErrorResponse"
			raise "Error while query URL #{url}: #{parsed_response["ErrorResponse"]["Error"]}"
		end
		if parsed_response["AssetChildrenResponse"]["AssetChildren"].has_key? "Assets"
			return parsed_response["AssetChildrenResponse"]["AssetChildren"]["Assets"]["Elements"]
		else
			return []
		end
	end
	
	def get_value_from_uri(baa_base_url, baa_username, baa_password, baa_role,uri)
		url = "#{baa_base_url}#{uri}?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}"
		response = RestClient.get URI.escape(url), :accept => :json 
		parsed_response = JSON.parse(response)
		if parsed_response.has_key? "ErrorResponse"
			raise "Error while query URL #{url}: #{parsed_response["ErrorResponse"]["Error"]}"
		end
		return parsed_response["AssetAttributeValueResponse"]["AssetAttributeValue"]["value"]
	end
	
	def get_property_value_from_uri(baa_base_url, baa_username, baa_password, baa_role,uri,propname)
		url = "#{baa_base_url}#{uri}/?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}"
		response = RestClient.get URI.escape(url), :accept => :json 
		parsed_response = JSON.parse(response)
		if parsed_response.has_key? "ErrorResponse"
			raise "Error while query URL #{url}: #{parsed_response["ErrorResponse"]["Error"]}"
		end
		if parsed_response["PropertySetInstanceChildrenResponse"]["PropertySetInstanceChildren"].has_key? "PropertyValues"
			parsed_response["PropertySetInstanceChildrenResponse"]["PropertySetInstanceChildren"]["PropertyValues"]["Elements"].each do |elt|
				return elt["value"] if elt["name"] == propname
			end
		end
		return []	
	end
	
	def get_server_dbkey_from_name(baa_base_url, baa_username, baa_password, baa_role,server)
      url = "#{baa_base_url}/query"
      url += "?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"
      url += "&BQUERY=SELECT NAME FROM \"SystemObject/Server\" WHERE NAME equals \"#{server}\""

      response = RestClient.get URI.escape(url), :accept => :json 
      parsed_response = JSON.parse(response)

      if parsed_response.has_key? "ErrorResponse"
        raise "Error: while query URL #{url}: #{parsed_response["ErrorResponse"]["Error"]}"
      end

	  dbkey = parsed_response["PropertySetClassChildrenResponse"]["PropertySetClassChildren"]["PropertySetInstances"]["Elements"][0]["dbKey"] rescue nil
      raise "Error: Could not find sever #{server}." if servuri.nil?
      
      return dbkey	
	end
	
	def get_server_uri_from_name(baa_base_url, baa_username, baa_password, baa_role,server)
      url = "#{baa_base_url}/query"
      url += "?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}&version=#{rest_version}"
      url += "&BQUERY=SELECT NAME FROM \"SystemObject/Server\" WHERE NAME equals \"#{server}\""

      response = RestClient.get URI.escape(url), :accept => :json 
      parsed_response = JSON.parse(response)

      if parsed_response.has_key? "ErrorResponse"
        raise "Error: while query URL #{url}: #{parsed_response["ErrorResponse"]["Error"]}"
      end

	  servuri = parsed_response["PropertySetClassChildrenResponse"]["PropertySetClassChildren"]["PropertySetInstances"]["Elements"][0]["uri"] rescue nil
      raise "Error: Could not find sever #{server}." if servuri.nil?
      
      return servuri	
	end
	
	def list_virtual_mgr(baa_base_url, baa_username, baa_password, baa_role)
		result = []
		url = "#{baa_base_url}/type/PropertySetClasses/SystemObject/Virtualization/"
		url += "?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}"
		response = RestClient.get URI.escape(url), :accept => :json 
		parsed_response = JSON.parse(response)["PropertySetClassChildrenResponse"]["PropertySetClassChildren"]["PropertySetInstances"]["Elements"]
		id = 0
		parsed_response.each do |elt|
			id += 1
			servname = elt["name"]
			url = "#{baa_base_url}#{elt["uri"]}/"
			url += "?username=#{baa_username}&password=#{baa_password}&role=#{baa_role}"
			response = RestClient.get URI.escape(url), :accept => :json 
			response = JSON.parse(response)["PropertySetInstanceChildrenResponse"]["PropertySetInstanceChildren"]["PropertyValues"]["Elements"]
			mgr = ""
			response.each do |serv|
				mgr = serv["value"] if serv["name"] == "VIRTUAL_ENTITY_TYPE"
			end
			uri = get_server_uri_from_name(baa_base_url, baa_username, baa_password, baa_role, servname)
			result << {"name" => servname, "id" => id, "mgr" => mgr, "uri" => uri}
		end
		return result
	end
	
    ########################################################################################
    #                                   SOAP SERVICES                                      #
    ########################################################################################



    def baa_soap_login(baa_base_url, baa_username, baa_password)
      client = Savon.client("#{baa_base_url}/services/BSALoginService.wsdl") do |wsdl, http|
         http.auth.ssl.verify_mode = :none 
      end

      response = client.request(:login_using_user_credential) do |soap|
        soap.endpoint = "#{baa_base_url}/services/LoginService"
        soap.body = {:userName => baa_username, :password => baa_password, :authenticationType => "SRP"}
      end

      session_id = response.body[:login_using_user_credential_response][:return_session_id]
    end

    def baa_soap_assume_role(baa_base_url, baa_role, session_id)
      client = Savon.client("#{baa_base_url}/services/BSAAssumeRoleService.wsdl") do |wsdl, http|
        http.auth.ssl.verify_mode = :none
      end

      client.http.read_timeout = 300

      reponse = client.request(:assume_role) do |soap|
        soap.endpoint = "#{baa_base_url}/services/AssumeRoleService"
        soap.header = {"ins0:sessionId" => session_id}
        soap.body = { :roleName => baa_role }
      end
    end

    def baa_soap_validate_cli_result(result)
      if result && (result.is_a? Hash)
        if result[:success] == false
          raise "Command execution failed: #{result[:error]}, #{result[:comments]}"
        end
        return result
      else
        raise "Command execution did not return a valid response: #{result.inspect}"
      end
      nil
    end

    def baa_soap_execute_cli_command_using_attachments(baa_base_url, session_id, namespace, command, args, payload)
      client = Savon.client("#{baa_base_url}/services/BSACLITunnelService.wsdl") do |wsdl, http|
        http.auth.ssl.verify_mode = :none
      end

      client.http.read_timeout = 300

      response = client.request(:execute_command_using_attachments) do |soap|
        soap.endpoint = "#{baa_base_url}/services/CLITunnelService"
        soap.header = {"ins1:sessionId" => session_id}
       
        body_details = { :nameSpace => namespace, :commandName => command, :commandArguments => args }
		
		if payload
			payload = Base64.encode64(payload)
			body_details.merge!({:payload => { :argumentNameArray => "fileName", :dataHandlerArray => [payload], :fileNameArray => "sentpayload"}})
		end

        soap.body = body_details
      end

      result = response.body[:execute_command_using_attachments_response][:return]
      return baa_soap_validate_cli_result(result)
    end

    def baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, namespace, command, args)
      client = Savon.client("#{baa_base_url}/services/BSACLITunnelService.wsdl") do |wsdl, http|
        http.auth.ssl.verify_mode = :none
      end
      
      client.http.read_timeout = 300

      response = client.request(:execute_command_by_param_list) do |soap|
        soap.endpoint = "#{baa_base_url}/services/CLITunnelService"
        soap.header = {"ins1:sessionId" => session_id}
        soap.body = { :nameSpace => namespace, :commandName => command, :commandArguments => args }
      end

      result = response.body[:execute_command_by_param_list_response][:return]
      return baa_soap_validate_cli_result(result)
    end
	
	def baa_soap_execute_cli_with_no_check(baa_base_url, session_id, namespace, command, args)
      client = Savon.client("#{baa_base_url}/services/BSACLITunnelService.wsdl") do |wsdl, http|
        http.auth.ssl.verify_mode = :none
      end
      
      client.http.read_timeout = 300

      response = client.request(:execute_command_by_param_list) do |soap|
        soap.endpoint = "#{baa_base_url}/services/CLITunnelService"
        soap.header = {"ins1:sessionId" => session_id}
        soap.body = { :nameSpace => namespace, :commandName => command, :commandArguments => args }
      end

      result = response.body[:execute_command_by_param_list_response][:return]
      return result
    end
	
	def baa_soap_get_uri_from_dbkey(baa_base_url, session_id, dbkey)
		return baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "GenericObject", "getRESTfulURI", [dbkey])[:return_value]
	end
	
	def baa_soap_get_vgp_by_group_and_name(baa_base_url, session_id, group, vgpname)
		vgpid = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Virtualization", "getVirtualGuestPackageIdByGroupAndName", [group,vgpname])[:return_value]
		return baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Virtualization", "getVirtualGuestPackage", [vgpid])[:return_value]
	end
	
	def baa_soap_get_uri_from_servername(baa_base_url, session_id, servername)
		dbkey = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Server", "getServerDBKeyByName", [servername])[:return_value]
		return baa_soap_get_uri_from_dbkey(baa_base_url, session_id, dbkey)
	end
	
	def baa_soap_execute_job_against(baa_base_url, baa_username, baa_password, baa_role, session_id, jobkey, targets)
		#first we remove all targets from the job
		jobkey = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Job", "clearTargetComponentGroups", [jobkey])[:return_value]
		jobkey = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Job", "clearTargetComponents", [jobkey])[:return_value]
		jobkey = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Job", "clearTargetGroups", [jobkey])[:return_value]
		jobkey = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Job", "clearTargetServers", [jobkey])[:return_value]
		# Adding the targets to the job
		targets.each do |t|
			case t.split("|")[0]
			when "SERVER"
				jobkey = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Job", "addTargetServer", [jobkey,t.split("|")[1]])[:return_value]
			when "COMPONENT"
				jobkey = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Job", "addTargetComponent", [jobkey,t.split("|")[2]])[:return_value]
			when "STATIC_SERVER_GROUP","SMART_SERVER_GROUP"
				jobkey = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Job", "addTargetGroup", [jobkey,"#{t.split("|")[1]}"])[:return_value]
			when "STATIC_COMPONENT_GROUP","SMART_COMPONENT_GROUP"
				jobkey = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Job", "addTargetComponentGroup", [jobkey,"#{t.split("|")[1]}"])[:return_value]
			end
		end
		# Run the job
		job_url = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "GenericObject", "getRESTfulURI", [jobkey])[:return_value]
		execute_job(baa_base_url, baa_username, baa_password, baa_role, job_url)
	end
	
    def baa_soap_create_blpackage_deploy_job(baa_base_url, session_id, job_folder_id, job_name, package_db_key, targets)
      if targets.nil? || targets.empty?
        raise "Atleast one target needs to be specified while creating a blpackage deploy job"
      end

      result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "DeployJob", "createDeployJob",
                  [
                    job_name,                       #deployJobName
                    job_folder_id,                  #groupId
                    package_db_key,                 #packageKey
                    1,                              #deployType (0 = BASIC, 1 = ADVANCED)
                    targets.first,                  #serverName
                    true,                           #isSimulateEnabled
                    true,                           #isCommitEnabled
                    false,                          #isStagedIndirect
                    2,                              #logLevel (0 = ERRORS, 1 = ERRORS_AND_WARNINGS, 2 = ALL_INFO)
                    true,                           #isExecuteByPhase
                    false,                          #isResetOnFailure
                    true,                           #isRollbackAllowed
                    false,                          #isRollbackOnFailure
                    true,                           #isRebootIfRequired
                    true,                           #isCopyLockedFilesAfterReboot
                    true,                           #isStagingAfterSimulate
                    true                            #isCommitAfterStaging
                  ])

      job_db_key = result[:return_value]
       
      targets.each do |t|
        unless (t == targets.first)
          baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "DeployJob", "addNamedServerToJobByJobDBKey", [job_db_key, t])
        end
      end

      job_db_key
    end

    def baa_soap_create_component_based_blpackage_deploy_job(baa_base_url, session_id, job_folder_id, job_name, package_db_key, targets)
      if targets.nil? || targets.empty?
        raise "Atleast one component needs to be specified while creating a component based blpackage deploy job"
      end

      result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "DeployJob", "createComponentBasedDeployJob",
                  [
                    job_name,                       #deployJobName
                    job_folder_id,                  #groupId
                    package_db_key,                 #packageKey
                    1,                              #deployType (0 = BASIC, 1 = ADVANCED)
                    targets.first,                  #componentKey
                    true,                           #isSimulateEnabled
                    true,                           #isCommitEnabled
                    false,                          #isStagedIndirect
                    2,                              #logLevel (0 = ERRORS, 1 = ERRORS_AND_WARNINGS, 2 = ALL_INFO)
                    true,                           #isExecuteByPhase
                    false,                          #isResetOnFailure
                    true,                           #isRollbackAllowed
                    false,                          #isRollbackOnFailure
                    true,                           #isRebootIfRequired
                    true,                           #isCopyLockedFiles
                    true,                           #isStagingAfterSimulate
                    true,                           #isCommitAfterStaging
                    false,                          #isSingleDeployModeEnabled
                    false,                          #isSUMEnabled
                    0,                              #singleUserMode
                    0,                              #rebootMode
                    false,                          #isMaxWaitTimeEnabled
                    "30",                           #maxWaitTime
                    false,                          #isMaxAgentConnectionTimeEnabled
                    60,                             #maxAgentConnectionTime
                    false,                          #isFollowSymlinks
                    false,                          #useReconfigRebootAtEndOfJob
                    0                               #overrideItemReconfigReboot
                  ])

      job_db_key = result[:return_value]
       
      targets.each do |t|
        unless (t == targets.first)
          baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "DeployJob", "addComponentToJobByJobDBKey", [job_db_key, t])
        end
      end

      job_db_key
    end

    def baa_soap_create_software_deploy_job(baa_base_url, session_id, job_folder_id, job_name, software_db_key, model_type, targets)
      if targets.nil? || targets.empty?
        raise "Atleast one target needs to be specified while creating a software deploy job"
      end

      result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "DeployJob", "createSoftwareDeployJob",
                  [
                    job_name,                       #deployJobName
                    job_folder_id,                  #groupId
                    software_db_key,                #objectKey
                    model_type,                     #modelType
                    targets.first,                  #serverName
                    true,                           #isSimulateEnabled
                    true,                           #isCommitEnabled
                    false,                          #isStagedIndirect
                    2,                              #logLevel (0 = ERRORS, 1 = ERRORS_AND_WARNINGS, 2 = ALL_INFO)
                    false,                          #isResetOnFailure
                    true,                           #isRollbackAllowed
                    false,                          #isRollbackOnFailure
                    true,                           #isRebootIfRequired
                    true                            #isCopyLockedFilesAfterReboot
                  ])

      job_db_key = result[:return_value]
       
      targets.each do |t|
        unless (t == targets.first)
          baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "DeployJob", "addNamedServerToJobByJobDBKey", [job_db_key, t])
        end
      end

      job_db_key
    end

    def baa_soap_create_file_deploy_job(baa_base_url, session_id, job_folder, job_name, source_file_list, destination_dir, targets)
      if targets.nil? || targets.empty?
        raise "Atleast one target needs to be specified while creating a file deploy job"
      end

      source_files_arg = source_file_list.join(",")
      targets_arg = targets.join(",")

      result = baa_soap_execute_cli_command_using_attachments(baa_base_url, session_id, "FileDeployJob", "createJobByServers",
                    [
                      job_name,                     #jobName
                      job_folder,                   #jobGroup
                      source_files_arg,             #sourceFiles
                      destination_dir,              #destination
                      false,                        #isPreserveSourceFilePaths
                      0,                            #numTargetsInParallel
                      targets_arg                   #targetServerNames
                    ], nil)

      return result[:return_value]
    end

    def baa_soap_job_group_to_id(baa_base_url, session_id, job_folder)
      result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "JobGroup", "groupNameToId", [job_folder])
      return result[:return_value]
    end

    def baa_soap_get_group_qualified_path(baa_base_url, session_id, group_type, group_id)
      result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Group", "getAQualifiedGroupName",
                  [
                    get_model_type_to_model_type_id(group_type),    #groupType
                    group_id                                        #groupId
                  ])

      qualified_name = result[:return_value]
    end

    def baa_soap_get_group_id_for_job(baa_base_url, session_id, job_key)
      result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Job", "getGroupId",
                  [
                    job_key,    #jobKey
                  ])

      group_id = result[:return_value]
    end

    def baa_soap_export_deploy_job_results(baa_base_url, session_id, job_folder, job_name, job_run_id)
      result = baa_soap_execute_cli_command_using_attachments(baa_base_url, session_id,
                    "Utility", "exportDeployRun", [job_folder, job_name, job_run_id, "/tmp/test.csv"], nil)
      if result && (result.has_key?(:attachment))
        attachment = result[:attachment]
        csv_data = Base64.decode64(attachment)
        return csv_data
      end
      nil
    end

    def baa_soap_export_snapshot_job_results(baa_base_url, session_id, job_folder, job_name, job_run_id, targets, export_format = "CSV")
      csv_data = ""
      targets.each do | target |
        result = baa_soap_execute_cli_command_using_attachments(baa_base_url, session_id,
                    "Utility", "exportSnapshotRun", [job_folder, job_name, job_run_id, "null", "null",
                        target, "/tmp/test.#{(export_format == "HTML") ? "html" : "csv"}", export_format], nil)
        if result && (result.has_key?(:attachment))
          attachment = result[:attachment]
          csv_data = csv_data + Base64.decode64(attachment) + "\n"
        end
      end
      csv_data
    end

    def baa_soap_export_nsh_script_job_results(baa_base_url, session_id, job_run_id)
      result = baa_soap_execute_cli_command_using_attachments(baa_base_url, session_id,
                    "Utility", "exportNSHScriptRun", [job_run_id, "/tmp/test.csv"], nil)
      if result && (result.has_key?(:attachment))
        attachment = result[:attachment]
        csv_data = Base64.decode64(attachment)
        return csv_data
      end
      nil
    end    

    def baa_soap_export_compliance_job_results(baa_base_url, session_id, job_folder, job_name, job_run_id, export_format = "CSV")
      result = baa_soap_execute_cli_command_using_attachments(baa_base_url, session_id,
                    "Utility", "exportComplianceRun", ["null", "null", "null", job_folder, job_name, job_run_id, 
                            "/tmp/test.#{(export_format == "HTML") ? "html" : "csv"}", export_format], nil)
      if result && (result.has_key?(:attachment))
        attachment = result[:attachment]
        csv_data = Base64.decode64(attachment)
        return csv_data
      end
      nil
    end

    def baa_soap_export_audit_job_results(baa_base_url, session_id, job_folder, job_name, job_run_id)
      result = baa_soap_execute_cli_command_using_attachments(baa_base_url, session_id,
                    "Utility", "simpleExportAuditRun", [job_folder, job_name, job_run_id, "/tmp/test.csv", ""], nil)
      if result && (result.has_key?(:attachment))
        attachment = result[:attachment]
        csv_data = Base64.decode64(attachment)
        return csv_data
      end
      nil
    end

    def baa_soap_db_key_to_rest_uri(baa_base_url, session_id, db_key)
      result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "GenericObject", "getRESTfulURI", [db_key])
      result[:return_value]
    end

    def baa_soap_map_server_names_to_rest_uri(baa_base_url, session_id, servers)
      targets = []
      servers.each do |server|
        result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "Server", "getServerDBKeyByName", [server])
        targets << baa_soap_db_key_to_rest_uri(baa_base_url, session_id, result[:return_value])
      end
      targets
    end

    def baa_create_bl_package_from_component(baa_base_url, session_id, package_name, depot_group_id, component_key)
      result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "BlPackage", "createPackageFromComponent",
                  [
                    package_name,       #packageName
                    depot_group_id,     #groupId
                    true,               #bSoftLinked
                    false,              #bCollectFileAcl
                    false,              #bCollectFileAttributes
                    true,               #bCopyFileContents
                    false,              #bCollectRegistryAcl
                    component_key,      #componentKey
                  ])

      bl_package_key = result[:return_value]
    end

    def baa_set_bl_package_property_value_in_deploy_job(baa_base_url, session_id, job_group_path, job_name, property, value_as_string)
      result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "DeployJob", "setOverriddenParameterValue",
                  [
                    job_group_path,     #groupName
                    job_name,           #jobName
                    property,           #parameterName
                    value_as_string     #valueAsString
                  ])

      deploy_job = result[:return_value]
    end
	
	def baa_set_nsh_script_property_value_in_job(baa_base_url, session_id, job_group_path, job_name, propindex, value_as_string)
      result = baa_soap_execute_cli_command_by_param_list(baa_base_url, session_id, "NSHScriptJob", "addNSHScriptParameterValueByGroupAndName",
                  [
                    job_group_path,     #groupName
                    job_name,           #jobName
                    propindex,           #parameterName
                    value_as_string     #valueAsString
                  ])

      deploy_job = result[:return_value]
    end

  end
end
