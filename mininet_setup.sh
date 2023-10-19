# create tmp folder for mininet machine
mkdir -p ./tmp/

# download mininet
if [ ! -f ./tmp/mininet-2.3.0-210211-ubuntu-20.04.1-legacy-server-amd64-ovf.zip ]; then
   wget -P tmp/ https://github.com/mininet/mininet/releases/download/2.3.0/mininet-2.3.0-210211-ubuntu-20.04.1-legacy-server-amd64-ovf.zip
fi

# extract mininet
if [ ! -f ./tmp/mininet-2.3.0-210211-ubuntu-20.04.1-legacy-server-amd64.ovf ]; then
   unzip -d ./tmp/ ./tmp/mininet-2.3.0-210211-ubuntu-20.04.1-legacy-server-amd64-ovf.zip
fi

# Specify the path to your OVF file and VM name
ovf_file="./tmp/mininet-2.3.0-210211-ubuntu-20.04.1-legacy-server-amd64.ovf"
vm_name="mininet"

# Import the virtual machine from the OVF file
if ! VBoxManage showvminfo "$vm_name" >/dev/null 2>&1; then
   VBoxManage import "$ovf_file" --vsys 0 --vmname "$vm_name"
fi

# Start the virtual machine
vm_state=$(VBoxManage showvminfo "$vm_name" --machinereadable | grep "VMState=" | cut -d'=' -f2)
if [[ $vm_state != "\"running\"" ]]; then
   VBoxManage startvm "$vm_name" --type headless
fi

# Wait for the virtual machine to boot
while true; do
   vm_state=$(VBoxManage showvminfo "$vm_name" --machinereadable | grep "VMState=" | cut -d'=' -f2)
   if [[ $vm_state == "\"running\"" ]]; then
      break
   fi
   sleep 1
done

# Get the IP address of the virtual machine
vm_ip=$(VBoxManage guestproperty get "$vm_name" "/VirtualBox/GuestInfo/Net/0/V4/IP" | cut -d' ' -f2)

# Copy l2_pair.py to mininet machine
scp -o StrictHostKeyChecking=no \
   -o UserKnownHostsFile=/dev/null \
   -i ./tmp/mininet.key ./l2_pair.py \
   mininet@"$vm_ip":/home/mininet/
