# create tmp folder for mininet machine
echo "create tmp folder for mininet machine"
mkdir -p ./tmp/

# download mininet
echo "download mininet"
if [ ! -f ./tmp/mininet-2.3.0-210211-ubuntu-20.04.1-legacy-server-amd64-ovf.zip ]; then
   wget -P tmp/ https://github.com/mininet/mininet/releases/download/2.3.0/mininet-2.3.0-210211-ubuntu-20.04.1-legacy-server-amd64-ovf.zip
fi

# extract mininet
echo "extract mininet"
if [ ! -f ./tmp/mininet-2.3.0-210211-ubuntu-20.04.1-legacy-server-amd64.ovf ]; then
   unzip -d ./tmp/ ./tmp/mininet-2.3.0-210211-ubuntu-20.04.1-legacy-server-amd64-ovf.zip
fi

# Specify the path to your OVF file and VM name
echo "Specify the path to your OVF file and VM name"
ovf_file="./tmp/mininet-2.3.0-210211-ubuntu-20.04.1-legacy-server-amd64.ovf"
vm_name="mininet"

# Import the virtual machine from the OVF file
echo "Import the virtual machine from the OVF file"
if ! VBoxManage showvminfo "$vm_name" >/dev/null 2>&1; then
   VBoxManage import "$ovf_file" --vsys 0 --vmname "$vm_name"
fi

# Set up SSH port forwarding from host 2222 to guest 22
echo "Set up SSH port forwarding from host 2222 to guest 22"
VBoxManage modifyvm "$vm_name" --natpf1 "guestssh,tcp,,2222,,22"

# Start the virtual machine
echo "Start the virtual machine"
vm_state=$(VBoxManage showvminfo "$vm_name" --machinereadable | grep "VMState=" | cut -d'=' -f2)
if [[ $vm_state != "\"running\"" ]]; then
   VBoxManage startvm "$vm_name" --type headless
fi

# Wait for the virtual machine to boot
echo "Wait for the virtual machine to boot"
while true; do
   vm_state=$(VBoxManage showvminfo "$vm_name" --machinereadable | grep "VMState=" | cut -d'=' -f2)
   if [[ $vm_state == "\"running\"" ]]; then
      break
   fi
   sleep 1
done

# Remove from known hosts
echo "Remove from known hosts"
ssh-keygen -f "/home/quanblue/.ssh/known_hosts" -R "[localhost]:2222"

# Add to known hosts
echo "Add to known hosts"
printf "exit\n" | sshpass -p "mininet" ssh -p 2222 mininet@localhost -o 'StrictHostKeyChecking=no'

# Copy l2_pairs.py to mininet machine
echo "Copy l2_pairs.py to mininet machine"
sshpass -p "mininet" scp -P 2222 ./l2_pairs.py mininet@localhost:~/pox/pox/forwarding
