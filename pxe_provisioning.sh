#!/bin/bash -x
PXE='PXE4640'
TARGET='TODO_4640'
PXESSH=9222
VMSSH=8222
VMHTTP=8080

vbmg() {
	VBoxManage.exe "$@";
}


createVM() {
	
	#Create VM
	vbmg createvm --name $1 --ostype "RedHat_64" --register

	local SED_PROGRAM="/^Config file:/ { s|^Config file: \+\(.\+\)\\\\.\+\.vbox|\1|; s|\\\\|/|gp }"
	local VM_FOLDER=$(vbmg showvminfo TODO_4640 | sed -ne "$SED_PROGRAM" | tr -d "\r\n")
	local NATNETWORK='NET_4640'
	local nat_result="$(vbmg natnetwork list NET_4640)"
	
	if [[ $nat_result =~ "1 network" ]]; then
		echo "$NATNETWORK net server already exists, remove... "
		vbmg natnetwork remove --netname "$NATNETWORK"
	fi

	#Set memory and network
	vbmg natnetwork add --netname "$NATNETWORK" --enable --dhcp off \
		--network 192.168.150.0/24 \
		--port-forward-4 "PXESSH:tcp:[]:$PXESSH:[192.168.150.10]:22" \
		--port-forward-4 "VMHTTP:tcp:[]:$VMHTTP:[192.168.150.200]:80" \
		--port-forward-4 "VMSSH:tcp:[]:$VMSSH:[192.168.150.200]:22"

	#Create Disk
	vbmg createmedium disk --filename "$VM_FOLDER/$1.vdi" --size 10240
	vbmg storagectl "$1" \
		--name "STORAGE4640" \
		--add sata --controller IntelAhci \
		--portcount 1
	vbmg storageattach "$1" --storagectl "STORAGE4640" --port 0 --device 0 --type hdd --medium  "$VM_FOLDER/$1.vdi"

	# Change setting
	vbmg modifyvm $1 \
		--memory 2048 \
		--nic1 natnetwork --nat-network1 $NATNETWORK --cableconnected1 on \
		--boot1 disk --boot2 net --boot3 none --boot4 none \
		--vram 24 \
		--graphicscontroller vmsvga \
		--pae on \
		--longmode on \
		--x2apic on
}

find_machine() {
	local status=$(vbmg list vms | grep "$1" | cut -d'"' -f2)
	if [ -z "$status" ]; then return 1; else return 0; fi
}

find_running_machine() {
	local status=$(vbmg list runningvms | grep "$1" | cut -d'"' -f2)
		if [ -z "$status" ]; then return 1; else return 0; fi
}

echo "Delete Legacy target VM"
if find_machine $TARGET; then vbmg unregistervm --delete $TARGET; fi
echo "Create Target VM"
createVM $TARGET
echo "Start PXE Server"
find_running_machine "$PXE" && vbmg controlvm $PXE acpipowerbutton
vbmg modifyvm $PXE --nic1 natnetwork --nat-network1 NET_4640 --cableconnected1 on
vbmg startvm $PXE
echo "Checking if PXE server is up"
while /bin/true; do
	ssh -i ~/.ssh/acit_admin_id_rsa -p $PXESSH -q -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@localhost exit
	if [ $? -ne 0 ]; then
		echo "PXE server is not up, sleeping..."
		sleep 5
	else
		break
	fi
done
echo "Copy all necessary files to PXE server"
scp -P$PXESSH -r -i ~/.ssh/acit_admin_id_rsa install.sh admin@localhost:/www/
scp -P$PXESSH -r -i ~/.ssh/acit_admin_id_rsa ks.cfg admin@localhost:/www/
#Start the VM
vbmg startvm $TARGET

spin='-\|/'
i=0
echo "Setting up todoapp... will take a few mins.."
while /bin/true; do
	output=`curl -Is localhost:$VMHTTP | head -n 1`
	if [[ $output =~ "HTTP/1.1 200 OK" ]]; then
		echo "Website is up! shutdown PXE server..."
		break
	else
		i=$(( (i+1) %4 ))
		printf "\r${spin:$i:1}"
		sleep .5
	fi
done

# Shutdown PXE server
vbmg controlvm $PXE acpipowerbutton

