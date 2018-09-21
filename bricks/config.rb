# Size of the CoreOS cluster created by Vagrant
$num_instances=1

# Used to fetch a new discovery token for a cluster of size $num_instances
$new_discovery_url="https://discovery.etcd.io/new?size=#{$num_instances}"

# Automatically replace the discovery token on 'vagrant up'

if File.exists?('user-data') && ARGV[0].eql?('up')
  require 'open-uri'
  require 'yaml'

  token = open($new_discovery_url).read

  data = YAML.load(IO.readlines('user-data')[1..-1].join)

  if data.key? 'coreos' and data['coreos'].key? 'etcd'
    data['coreos']['etcd']['discovery'] = token
  end

  if data.key? 'coreos' and data['coreos'].key? 'etcd2'
    data['coreos']['etcd2']['discovery'] = token
  end

  # Fix for YAML.load() converting reboot-strategy from 'off' to `false`
  if data.key? 'coreos' and data['coreos'].key? 'update' and data['coreos']['update'].key? 'reboot-strategy'
    if data['coreos']['update']['reboot-strategy'] == false
      data['coreos']['update']['reboot-strategy'] = 'off'
    end
  end

  yaml = YAML.dump(data)
  File.open('user-data', 'w') { |file| file.write("#cloud-config\n\n#{yaml}") }
end

PERSISTENT_DISK_DIR = File.join(File.expand_path('~'), '.bricks-data')
PERSISTENT_DISK = File.join(PERSISTENT_DISK_DIR, 'persistent_data.vdi')
MACHINE_ID_FILE= File.join(File.expand_path('~'),'.bricks/clusters/coreos-vagrant/.vagrant/machines/core-01/virtualbox/id')

def machine_id
    File.exists?(MACHINE_ID_FILE)? File.read(MACHINE_ID_FILE) : ""
end

def custom_config(config)
  if File.exist?(MACHINE_ID_FILE)
    config.trigger.before :destroy do |trigger|
      trigger.info = "detach virtual disk"
      trigger.run = { inline: "VBoxManage storageattach '#{machine_id}' --storagectl 'persistent_data' --port 0 --medium none" }
    end
  end

  if not File.exist?(PERSISTENT_DISK)
    config.vm.provider :virtualbox do |v|
      FileUtils.mkdir_p(PERSISTENT_DISK_DIR)
      v.customize ['createmedium', '--filename', PERSISTENT_DISK, '--size', (20 * 1024)]
    end
  end

  if not File.exist?(MACHINE_ID_FILE)
    config.vm.provider :virtualbox do |v|
      v.customize ['storagectl', :id, '--name', 'persistent_data', '--add', 'sata', '--hostiocache', 'off']
    end
  end

  config.vm.provider :virtualbox do |v|
    v.customize ['storageattach', :id, '--storagectl', 'persistent_data', '--port', 0, '--type', 'hdd', '--medium', PERSISTENT_DISK, '--hotpluggable', 'on', '--discard', 'on', '--setuuid', 'b121c145-c02E-05FF-FFFF-17A812A1717F']
  end
end

#
# coreos-vagrant is configured through a series of configuration
# options (global ruby variables) which are detailed below. To modify
# these options, first copy this file to "config.rb". Then simply
# uncomment the necessary lines, leaving the $, and replace everything
# after the equals sign..

# Change basename of the VM
# The default value is "core", which results in VMs named starting with
# "core-01" through to "core-${num_instances}".
#$instance_name_prefix="core"

# Log the serial consoles of CoreOS VMs to log/
# Enable by setting value to true, disable with false
# WARNING: Serial logging is known to result in extremely high CPU usage with
# VirtualBox, so should only be used in debugging situations
#$enable_serial_logging=false

# Enable port forwarding of Docker TCP socket
# Set to the TCP port you want exposed on the *host* machine, default is 2375
# If 2375 is used, Vagrant will auto-increment (e.g. in the case of $num_instances > 1)
# You can then use the docker tool locally by setting the following env var:
#   export DOCKER_HOST='tcp://127.0.0.1:2375'
#$expose_docker_tcp=2375

# Set the final octet of the IP address
# The first host will begin at ${ip_prefix}.${ip_range_start}
# Each subsequent host will take the next IP address in the sequence
$ip_range_start = '50'

# Set the IP address prefix for the VM
# All hosts in the cluster will use the following prefix for the IP
$ip_range_prefix = '192.168.42'

# Enable NFS sharing of your home directory ($HOME) to CoreOS
# It will be mounted at the same path in the VM as on the host.
# Example: /Users/foobar -> /Users/foobar
#$share_home=false
$share_home=true

# Customize VMs
#$vm_gui = false
#$vm_memory = 1024
$vm_memory = 6144
#$vm_cpus = 1
$vm_cpus = 2
#$vb_cpuexecutioncap = 100

# Customize VMs
#$vm_gui = false
#$vm_memory = 1024
#$vm_cpus = 1
#$vb_cpuexecutioncap = 100

# Share additional folders to the CoreOS VMs
# For example,
# $shared_folders = {'/path/on/host' => '/path/on/guest', '/home/foo/app' => '/app'}
# or, to map host folders to guest folders of the same name,
# $shared_folders = Hash[*['/home/foo/app1', '/home/foo/app2'].map{|d| [d, d]}.flatten]
#$shared_folders = {}
$shared_folders = {'/var/log/amobee' => '/var/log/amobee', '/etc/amobee' => '/etc/amobee',  '/var/amobee' => '/tmp/var/amobee'}

# Enable port forwarding from guest(s) to host machine, syntax is: { 80 => 8080 }, auto correction is enabled by default.
$forwarded_ports = { 8443 => 8443 }
$update_channel='beta'
