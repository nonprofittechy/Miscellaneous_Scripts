##############################################################
#
#				Decommission User Accounts - decommission.ps1
#				Purpose: deletes user accounts in predefined OU
#				1. Archive U: drive folder
#				2. Archive S: drive folder
#				3. Delete AD account
#
##############################################################


# Use implicit remoting to connect to Mail Server for Exchange cmdlets (and account decommissioning)
$session = new-pssession -configurationname Microsoft.exchange -connectionuri http://mail.domain.org/powershell
import-pssession -DisableNameChecking $session | out-null
import-module -DisableNameChecking activedirectory | out-null

#################################
# Initialize variables

$ouForArchivedAccounts = "OU=ArchiveMe,OU=_Domain_Users,DC=DOMAIN,DC=local"
$date = get-date -format "yyyy-MM-dd-hh-mm"
$archiveRoot = "\\DOMAIN.local\shares\Archive\"
$dfsShareRoot = "\\DOMAIN.local\shares\"
$archiveSPath = join-path $archiveRoot "Archived Folders"
$archiveUPath = join-path $archiveRoot "Users"
$logFilePath = $date + "-decommission.log"
$robocopyLog = $date + "-folders and files moved.log"

# find enabled user accounts in the specified OU
$accountsToDecommission = Get-ADUser -filter * -properties Department,HomeDirectory,userSharedFolder -searchbase $ouForArchivedAccounts

#########################################################################################
# Child Functions
# Decommission may be given either a single AD user object, or an array of user objects
function Decommission($accounts) {
	outputLog("Decommissioning run for $date")
	outputLog("View status of folders and files that were archived in $robocopyLog")
	
	if (!$accounts.count) { 
		decommissionUser($accounts)
	} else {
		foreach ($user in $accounts) {
			decommissionUser($user)
		}
	}
}

function decommissionUser($user) {
		outputLog("`r`nDecommissioning user ($user.Name)")
		write-host "`r`nDecommissioning user " $user.Name
		ArchiveU $user $global:archiveUPath
		ArchiveS $user $global:archiveSPath
		DeleteADAccount $user
}

####################################
# $path is the path prefix where the folder will be archived
# $user is a full user object, which includes the homeDirectory attribute
function ArchiveU($user, $path) {
	if ($user.HomeDirectory -and (test-path $user.HomeDirectory)) {
		$archiveUserPath = join-path -path $archiveUPath -childpath $user.samAccountName
		ArchiveFolder -oldpath $user.HomeDirectory -newpath $archiveUserPath -logfile $robocopyLog
	} else {
		OutputLog("Couldn't find U: drive folder " + ($user.homeDirectory) + " for " + ($user.DisplayName) + ($user.samAccountName))
	}
} 

####################################
# $path is the path prefix where the folder will be archived
# $user is a full user object, which includes the userSharedFolder attribute
# The path will be adjusted to a relative path
function ArchiveS($user, $path) {
	if ($user.userSharedFolder -and (test-path $user.userSharedFolder)) {
		$relPath = getRelativePath $user.userSharedFolder
		$newPath = join-path $archiveSPath $relPath
		ArchiveFolder -oldpath $user.userSharedFolder -newpath $newPath -logfile $robocopyLog
	} else {
		OutputLog("Couldn't find S: drive folder " + ($user.userSharedFolder) + " for " + ($user.DisplayName) + " " + ($user.samAccountName))
	}
}

function ArchiveFolder($oldPath, $newPath, $logFile) {
	OutputLog "Archiving folder ($oldpath) to ($newpath)"
	write-host "Archiving folder ($oldpath) to ($newpath)"
	write-host "robocopy" ($oldPath) ($newPath) "/E /SEC /COPY:DATSO /MOVE /V /NP /R:10 /W:30 /NJS /NJH /log+:$logFile"
	robocopy ($oldPath) ($newPath) /E /SEC /COPY:DATSO /MOVE /V /NP /R:10 /W:30 /NJS /NJH /log+:$logFile
	if (!($?)) {
		OutputLog("Error moving $oldpath with Robocopy. Please review '$logfile' for details.")
	}
}


##################################
# Delete the ADUser and any child objects (such as ActiveSync objects)
# see: http://andrewbeaton.net/faq/2012/07/04/cannot-remove-ad-user-with-nested-leaf-objects/ for sample code
function DeleteADAccount($user) {
	write-host "Deleting AD user " $user.samAccountName " (" $user ")"
	OutputLog "Deleting AD user " $user.samAccountName " (" $user ")"
	RemoveChildObjects -user $user
	Remove-ADUser -identity $user.samAccountName -confirm:$false
}

function RemoveChildObjects($user) {
	Get-ActiveSyncDevice -Mailbox $user.samAccountName | Remove-ActiveSyncDevice -Confirm:$false
	OutputLog "Deleting Exchange ActiveSync objects for ($user.samAccountName)."
	get-ADObject -filter * -SearchScope oneLevel -SearchBase $user.DistinguishedName | Remove-ADObject -recursive -Confirm:$false
}

#################################
#	This will dumbly replace the path in $dfsShareRoot with the empty string
#	This could therefore break if the dfsShareRoot is incorrect or is repeated anywhere in the path
#	There is also no check that the given path makes sense
function getRelativePath($path) {
	return $path -ireplace ([regex]::escape($dfsShareRoot)), ""
}

function outputLog($data) {
	$data >> $logFilePath
}

#################################
# Run the main program
if ($accountsToDecommission) {
	Decommission($accountsToDecommission)
} else {
	write-host "No enabled users were found in" $ouForArchivedAccounts ". Move an ENABLED user account to" $ouForArchivedAccounts "in order to archive it with this script."
}
	Write-Host -NoNewLine "Press any key to continue..."
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")