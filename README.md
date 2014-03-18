RPMBAAExt
=========

Resource automation and automation script extension for RPM and BLadeLogic integration. This extension provide following automation:
- run job against targets that can be servers, servers group, components, components group.
- provision Virtual Machine
- operation on virtual machine: start, stop and delete.

Install
=======

On your BRPM installation in directory <BRPM install dir>/WEB-INF/lib/script_support, save/rename baa_utilities.rb and script_helper.rb.

On <BRPM install dir>/WEB-INF/lib/script_support/LIBRARY/automation/BMC Application Automation 8.2, save/rename baa_execute_job_against.rb.

Copy baa_utilities.rb and script_helper.rb to <BRPM install dir>/WEB-INF/lib/script_support

Files in automation directories need to be copied on BRPM server to:
  <BRPM install dir>/WEB-INF/lib/script_support/LIBRARY/automation/BMC Application Automation 8.2
  
Files resource_automation need to be copied on BRPM server to:
  <BRPM install dir>/WEB-INF/lib/script_support/LIBRARY/resource_automation/BMC Application Automation 8.2

Then you need to restart BRPM as baa_utilities.rb file has been changed.

Setup
=====

You need to create an integration server pointing to your BladeLogic server to point the API (if not already done):

```
  Server Name:  <up to you>
  Server URL:   <BladeLogic Webservice url; example: https://bl-appserver:9843>
  Username:     <BLadeLogic user>
  password:     <password of previously defined user>
  Details:	role: <role you want to use; example BLAdmins>
			authentication_mode: <example: SRP>
```

You need to import in automation (Environment -> Automation):
  1. The resource automation script that you associate with previously defined integration server:
    - **baa_job_gtargets.rb**: provide multi selection three for targets allowing to select groups
    - **baa_vgp.rb**: provide the list of virtual guest package using VM template for a defined hypervisor type
    - **baa_vgp_target.rb**: provide a single select tree of possible location for the VM to be provisioned
    - **baa_list_vm.rb**: provide a multiple select tree of existing VMs for a defined hypervisor type
  2. The automation scripts that you associate with previously defined integration server
    - **baa_execute_job_against.rb**: execute an existing BladeLogic job to targets you specify, this using the resource baa_job_gtargets.rb
    - **baa_provision_vm.rb**: provision a VM from following inputs:
      - Hypervisor: hypervisor type like VMWare, Solaris, XenServer, RHEV, HyperV
      - VMTemplate: Virtual Guest Package to use
      - Location: Location where the VM will be provision
      - IPResolution: File (etc/hosts) or DNS
      - DHCP: to tell if the VM will get IP from DHCP
      - IPaddress: if DHCP is set to no, the IP to use
      - SubnetMask: if DHCP is set to no, the subnet mask to use
      - Gateway: if DHCP is set to no, the gateway to use
      - Hostname: the name and hostname of the VM to be provisioned
      - DNS: optional, IP of a DNS server to be used by the VM
      - Domain: optional, primary domain of the VM
    - **baa_vm_operation.rb**: apply operation to selected VMs using the following inputs:
      - Hypervisor: hypervisor type like VMWare, Solaris, XenServer, RHEV, HyperV
      - Action: action to apply to the selected VMs that can be stop, start and delete
      - VMs: VMs on which to apply the acation.

To be able to use the VM provisioning automation, you'll need to fist setup the followin content in BladeLogic:
  1. In the Depot folder, create the directory path: BRPM/Provisioning, then put the VGP that you want to be able to use to provision VMs in this folder. Those VGP need to be template based.
  2. In the Jobs folder, create the directory path: BRPM/Provisioning. The povisioning jobs will be create on this location.
  3. If you want the provisioning automation to update the IP resolution then you need to do the following:
    * create in BRPM/Provisioning an NSH Job named: Update IP resolution
    * This job need to have 3 parameters in the following order (name of parameters is not important):
      * Resolution Type: type of resolution, entry provided will be File or DNS
      * IP Address: Ip address to be resolved to the provided hostname
      * Hostname: hostname to be resolved to the provided IP address
    * the job need to be associated with the targets on which the IP resolution needs to be updated
  4. If you want the provisioning automation to update the server properties of the VM that has been provisionned in BLadeLogic, then you need to:
    * create an Update Server Properties Job in the Jobs folder BRPM/Provisioning that has to be named: Update properties
    * be sure that the hostname you've provided for the VM you provision is resolved after the VM is provisioned by at least the BladeLogic server or the job won't be able to update the server properties and the automation will fail.
      
Improvments
===========

For VM provisioning/management:
  1. Finish the implementation to manage other hypervisor type than VMware.
  2. Implement more actions like for exemple: snapshot, rollback VMs
  3. Add a provisioning automation allowing to provision several VMs from the same step using selected list of servers 
     on the step

Other:
  review all the automation that allows to selection targets for groups can be selected.

