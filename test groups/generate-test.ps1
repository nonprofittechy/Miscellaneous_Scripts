#########################################
#	generate-test.ps1
#	Generate a test user group, with representation from each unit
#	Prompt for new group name at command line
#
#########################################

import-module activedirectory

###################################
# Variables

$unitsPath = "s:\units.txt"

$ouForNewGroup = "OU=Test Groups,OU=Groups,OU=_Domain_Users,DC=DOMAIN,DC=local"

###################################
# Initialize variables
$units = get-content $unitsPath

###################################
# Functions

########################################
# Return a single, random user from the selected AD group
# $groupName is samAccountName, SID, or DN
function selectRandomGroupMember($groupName) {
	
	$group = get-adgroup $groupName
	
	$groupMembers = get-aduser -filter {(memberof -eq $group.distinguishedName) -and (enabled -eq $true)}
	
	$rand = new-object System.Random
	
	$user = $groupMembers[$rand.Next(0, $groupMembers.Count)]
	
	return $user
}

##################################
# Generate a list of users, one from each group provided
# groupList should be an array of group samAccountNames, SIDs, or distinguished names
# return type: array of user objects
function randomUserList($groupList) {
	$users = @()
	foreach ($group in $groupList) {
		$users += selectRandomGroupMember($group)
	}
	return $users
}

function createGroup($groupName, $ou, $groupMembers) {
	new-adgroup -path $ou -name $groupName -samAccountName $groupName -GroupScope "Global"
	$group = get-adgroup $groupName
	
	add-adgroupmember $group -members $groupMembers
}

###################################
# Program execution
write-host "This script will create a new test group with one randomly selected user per unit."
$groupName = read-host "Name of test group"

$groupMembers = randomUserList($units)

createGroup -groupName $groupName -OU $ouForNewGroup -groupMembers $groupMembers

write-host "Newly created group has been named" $groupName "and will be placed in the OU" $ouForNewGroup

write-host "Group Members are"
get-adgroupmember $groupName | select SamAccountName, Name | ft