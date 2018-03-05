function Add-HostProfilePortgroup{
  <#
  .SYNOPSIS
    Add a virtual machine portgroup to a host profile
  .DESCRIPTION
    Add a virtual machine portgroup to a host profile. Contains some hard coded network policy
    configurations specific to an environment
  .NOTES
    Author:  Mike McDowell
  .PARAMETER vlanID
    The VLAN tag to be used by the virtual machine portgroup
  .PARAMETER HostProfile
    The host profile that will have the virtual machine portgroup added to it
  .PARAMETER vSwitch
    The vSwitch to used by the new portgroup
  .PARAMETER PortGroupName
    The name of the new portgroup
  .EXAMPLE
    Add-HostProfilePortgroup -vlanID 1234 -HostProfile General-Hosts-01 -vSwitch vSwitch2 -PortgroupName "VLAN 1234 10.2.34.0/24"
    #>
    param(
      [int]$vlanID,
      [string]$HostProfile,
      [string]$vSwitch,
      [string]$PortGroupName
      )
    begin{
      if($vlanid -gt 4096){
        throw "Error: Invalid VLAN ID"
        break
      }


      function Copy-Property ($From, $To, $PropertyName ="*")
    {
        foreach ($p in Get-Member -In $From -MemberType Property -Name $propertyName)
        {        trap {
                        Add-Member -In $To -MemberType NoteProperty -Name $p.Name -Value $From.$($p.Name) -Force
                        continue
                        }
        $To.$($P.Name) = $From.$($P.Name)
        #Write-Output $P.Name
        }
      }
    }
    process{
      try{
        $hp = Get-VMHostProfile -Name $HostProfile
        }catch{
          $_
          break
        }


      $spec = New-Object VMware.Vim.HostProfileCompleteConfigSpec
      try{
        Copy-Property -From $hp.ExtensionData.Config -To $spec
        }catch{
          Throw "Unable to copy properties from host profile"          
          break
        }

       
      $vlanpol = New-Object VMware.Vim.ProfilePolicy
      $vlanpol.Id = "VlanIdPolicy"
      $vlanpol.PolicyOption = New-Object VMware.Vim.PolicyOption
      $vlanpol.PolicyOption.Id = "FixedVlanIdOption"
      $vlanpol.PolicyOption.Parameter += New-Object VMware.Vim.KeyAnyValue
      $vlanpol.PolicyOption.Parameter[0].Key = "vlanId"
      $vlanpol.PolicyOption.Parameter[0].Value =  [int]$vlanID


      $vswitchpol = New-Object VMware.Vim.ProfilePolicy
      $vswitchpol.Id = "VswitchSelectionPolicy"
      $vswitchpol.PolicyOption = New-Object VMware.Vim.PolicyOption
      $vswitchpol.PolicyOption.Id = "FixedVswitchSelectionOption"
      $vswitchpol.PolicyOption.Parameter += New-Object VMware.Vim.KeyAnyValue
      $vswitchpol.PolicyOption.Parameter[0].Key = "vswitchName"
      $vswitchpol.PolicyOption.Parameter[0].Value = $vSwitch

      $netpol = @(New-Object VMware.Vim.ProfilePolicy)

      $netpol[0].PolicyOption = New-Object VMware.Vim.PolicyOption
      $netpol[0].Id = "NetworkSecurityPolicy"
      $netpol[0].PolicyOption.Id = "NewFixedSecurityPolicyOption"

      $netpol += New-Object VMware.Vim.ProfilePolicy
      $netpol[1].PolicyOption = New-Object VMware.Vim.PolicyOption
      $netpol[1].Id = "NetworkTrafficShapingPolicy"
      $netpol[1].PolicyOption.Id = "NewFixedTrafficShapingPolicyOption"

      $netpol += New-Object VMware.Vim.ProfilePolicy
      $netpol[2].PolicyOption = New-Object VMware.Vim.PolicyOption
      $netpol[2].Id = "NetworkNicTeamingPolicy"
      $netpol[2].PolicyOption.Id = "FixedNicTeamingPolicyOption"

      $netpol += New-Object VMware.Vim.ProfilePolicy
      $netpol[3].PolicyOption = New-Object VMware.Vim.PolicyOption
      $netpol[3].Id = "NetworkNicOrderPolicy"
      $netpol[3].PolicyOption.Id = "UseDefault"

      $netpol += New-Object VMware.Vim.ProfilePolicy
      $netpol[4].PolicyOption = New-Object VMware.Vim.PolicyOption
      $netpol[4].Id = "NetworkFailoverPolicy"
      $netpol[4].PolicyOption.Id = "NewFixedFailoverCriteria"

      $portpol = New-Object VMware.Vim.ProfilePolicy
      $portpol.Id = "PortgroupCreatePolicy"
      $portpol.PolicyOption = New-Object VMware.Vim.PolicyOption
      $portpol.PolicyOption.Id = "CreateAlways"

      $myport = New-Object VMware.Vim.VmPortGroupProfile
      $myport.Name= $PortGroupName
      $myport.Enabled=$true
      $myport.Key="key-vim-profile-host-VmPortgroupProfile-$PortGroupName"
      $myport.NetworkPolicy=New-Object VMware.Vim.NetworkPolicyProfile
      $myport.Vlan=New-Object VMware.Vim.VlanProfile
      $myport.Vswitch=New-Object VMware.Vim.VirtualSwitchSelectionProfile
      $myport.ProfileTypeName="VmPortGroupProfile"
      $myport.ProfileVersion="6.5.0"
      $myport.Policy=$portpol

      $myport.Vlan.Policy=$vlanpol
      $myport.vlan.enabled=$true
      $myport.vlan.ProfileTypeName="VlanProfile"
      $myport.vlan.ProfileVersion="6.5.0"

      $myport.Vswitch.Policy=$vswitchpol
      $myport.Vswitch.enabled=$true
      $myport.Vswitch.ProfileTypeName="VirtualSwitchSelectionProfile"
      $myport.Vswitch.ProfileVersion="6.5.0"

      $myport.NetworkPolicy.policy=$netpol
      $myport.NetworkPolicy.enabled=$true
      $myport.NetworkPolicy.ProfileTypeName="NetworkPolicyProfile"
      $myport.NetworkPolicy.ProfileVersion="6.5.0"



      try{
        $spec.ApplyProfile.Network.VmPortGroup += @($myport)
        }catch{
          throw "Unable to add portgroup to host profile specification: $_"
          break
        }

      #Write-Output $spec.ApplyProfile.Network.VmPortGroup



      try{
        $hp.ExtensionData.UpdateHostProfile($spec)
        }catch{
          throw "Unable to write to host profile: $_"
          break
        }
    }
  }