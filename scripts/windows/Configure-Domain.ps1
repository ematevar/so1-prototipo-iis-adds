[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param([Parameter(Mandatory)][ValidateSet('Forest','AdditionalDC')][string]$Mode,[string]$DomainName='ad.so1.test')
$ErrorActionPreference='Stop'
$expectedName=if($Mode -eq 'Forest'){'DC01'}else{'DC02'}
if($env:COMPUTERNAME -ne $expectedName){throw "Renombrar y reiniciar esta VM como $expectedName antes de promoverla."}
if(-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME,"Instalar AD DS/DNS y promover como $Mode en $DomainName")){return}
Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools | Out-Null
Import-Module ADDSDeployment
$dsrm=Read-Host 'Contraseña DSRM (no se guarda en el repositorio)' -AsSecureString
if($Mode -eq 'Forest'){
 Install-ADDSForest -DomainName $DomainName -DomainNetbiosName SO1LAB -InstallDns -SafeModeAdministratorPassword $dsrm -NoRebootOnCompletion:$true -Force:$true
}else{
 $credential=Get-Credential -Message 'Cuenta autorizada para agregar el controlador al dominio'
 Install-ADDSDomainController -DomainName $DomainName -Credential $credential -InstallDns -SafeModeAdministratorPassword $dsrm -NoRebootOnCompletion:$true -Force:$true
}
Write-Output 'Promoción solicitada. Revisar el resultado; reiniciar la VM manualmente antes de continuar.'
