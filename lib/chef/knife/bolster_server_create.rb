#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2010-2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife/bolster_base'

class Chef
  class Knife
    class BolsterServerCreate < Knife

      include Knife::BolsterBase

      deps do
        require 'fog'
        require 'readline'
        require 'chef/json_compat'
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps
      end

      banner "knife bolster server create (options)"

      attr_accessor :initial_sleep_delay

      def run

        $stdout.sync = true

        Chef::Config[:knife][:template_file] = false
        Chef::Config[:knife][:distro] = bag_data['chef_distro']

        msg_pair("Chef Distro", Chef::Config[:knife][:distro])

        validate!

        server = connection.servers.create(create_server_def)

        msg_pair("Instance ID", server.id)
        msg_pair("Flavor", server.flavor_id)
        msg_pair("Image", server.image_id)
        msg_pair("Region", connection.instance_variable_get(:@region))
        msg_pair("Availability Zone", server.availability_zone)
        msg_pair("Security Groups", server.groups.join(", "))
        msg_pair("SSH Key", server.key_name)

        print "\n#{ui.color("Waiting for server", :magenta)}"

        # wait for it to be ready to do stuff
        server.wait_for { print "."; ready? }

        puts

        msg_pair("Tagging this node",config[:chef_node_name])

        connection.create_tags(server.id,{"Name" => config[:chef_node_name]})

        puts("\n")

        if vpc_mode?
          msg_pair("Subnet ID", server.subnet_id)
        else
          msg_pair("Public DNS Name", server.dns_name)
          msg_pair("Public IP Address", server.public_ip_address)
          msg_pair("Private DNS Name", server.private_dns_name)
        end
        msg_pair("Private IP Address", server.private_ip_address)

        print "\n#{ui.color("Waiting for sshd", :magenta)}"

        fqdn = vpc_mode? ? server.private_ip_address : server.dns_name

        print(".") until tcp_test_ssh(fqdn) {
          sleep @initial_sleep_delay ||= (vpc_mode? ? 40 : 10)
          puts("done")
        }

        bootstrap_for_node(server,fqdn).run

        puts "\n"
        msg_pair("Instance ID", server.id)
        msg_pair("Flavor", server.flavor_id)
        msg_pair("Image", server.image_id)
        msg_pair("Region", connection.instance_variable_get(:@region))
        msg_pair("Availability Zone", server.availability_zone)
        msg_pair("Security Groups", server.groups.join(", "))
        msg_pair("SSH Key", server.key_name)
        msg_pair("Root Device Type", server.root_device_type)
        if server.root_device_type == "ebs"
          device_map = server.block_device_mapping.first
          msg_pair("Root Volume ID", device_map['volumeId'])
          msg_pair("Root Device Name", device_map['deviceName'])
          msg_pair("Root Device Delete on Terminate", device_map['deleteOnTermination'])

          if config[:ebs_size]
            if ami.block_device_mapping.first['volumeSize'].to_i < config[:ebs_size].to_i
              volume_too_large_warning = "#{config[:ebs_size]}GB " +
                          "EBS volume size is larger than size set in AMI of " +
                          "#{ami.block_device_mapping.first['volumeSize']}GB.\n" +
                          "Use file system tools to make use of the increased volume size."
              msg_pair("Warning", volume_too_large_warning, :yellow)
            end
          end
        end
        if vpc_mode?
          msg_pair("Subnet ID", server.subnet_id)
        else
          msg_pair("Public DNS Name", server.dns_name)
          msg_pair("Public IP Address", server.public_ip_address)
          msg_pair("Private DNS Name", server.private_dns_name)
        end
        msg_pair("Private IP Address", server.private_ip_address)
        msg_pair("Environment", config[:environment] || '_default')
        msg_pair("Initial Run List", config[:initial_run_list].join(', '))
      end

      def bootstrap_for_node(server,fqdn)
        bootstrap = Chef::Knife::Bootstrap.new
        bootstrap.name_args = [fqdn]
        bootstrap.config[:run_list] = config[:initial_run_list]
        bootstrap.config[:ssh_user] = config[:ssh_user]
        bootstrap.config[:identity_file] = config[:identity_file]
        bootstrap.config[:chef_node_name] = config[:chef_node_name] || server.id
        bootstrap.config[:prerelease] = config[:prerelease]
        bootstrap.config[:bootstrap_version] = locate_config_value(:bootstrap_version)
        bootstrap.config[:distro] = locate_config_value(:distro)
        bootstrap.config[:use_sudo] = true unless config[:ssh_user] == 'root'
        bootstrap.config[:template_file] = locate_config_value(:template_file)
        bootstrap.config[:environment] = config[:environment]
        # may be needed for vpc_mode
        bootstrap.config[:no_host_key_verify] = config[:no_host_key_verify]
        bootstrap
      end

      def vpc_mode?
        # Amazon Virtual Private Cloud requires a subnet_id. If
        # present, do a few things differently
        !!config[:subnet_id]
      end

      def ami
        @ami ||= connection.images.get(locate_config_value(:image))
      end

      def validate!

        super([:image, :aws_ssh_key_id, :aws_access_key_id, :aws_secret_access_key])

        if ami.nil?
          ui.error("You have not provided a valid image (AMI) value.  Please note the short option for this value recently changed from '-i' to '-I'.")
          exit 1
        end
      end

      def create_server_def
        server_def = {
          :image_id => locate_config_value(:image),
          :groups => config[:security_groups],
          :flavor_id => locate_config_value(:flavor),
          :key_name => Chef::Config[:knife][:aws_ssh_key_id],
          :availability_zone => locate_config_value(:availability_zone)
        }

        server_def[:subnet_id] = config[:subnet_id] if config[:subnet_id]

        if ami.root_device_type == "ebs"
          ami_map = ami.block_device_mapping.first
          ebs_size = begin
                       if config[:ebs_size]
                         Integer(config[:ebs_size]).to_s
                       else
                         ami_map["volumeSize"].to_s
                       end
                     rescue ArgumentError
                       puts "--ebs-size must be an integer"
                       msg opt_parser
                       exit 1
                     end
          delete_term = if config[:ebs_no_delete_on_term]
                          "false"
                        else
                          ami_map["deleteOnTermination"]
                        end
          server_def[:block_device_mapping] =
            [{
               'DeviceName' => ami_map["deviceName"],
               'Ebs.VolumeSize' => ebs_size,
               'Ebs.DeleteOnTermination' => delete_term
             }]
        end

        server_def
      end
    end
  end
end
