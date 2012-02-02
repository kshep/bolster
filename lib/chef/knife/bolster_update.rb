require 'chef/knife/bolster_base'
require 'chef/knife/bolster_server_create'
require 'chef/data_bag_item'
require 'ruby-debug'

class Chef
  class Knife
    class BolsterUpdate < Knife

      include Knife::BolsterBase

      deps do
        require 'chef/knife/ssh'
        require 'fog'
        require 'readline'
        require 'chef/json_compat'
        require 'chef/knife/bootstrap'
        Chef::Knife::Ssh.load_deps
        Chef::Knife::Bootstrap.load_deps
      end

      banner "knife bolster update (options)"

      def create_node(params)

        name = params['node_name']

        puts
        msg_pair('--- Creating Node', name)

        aws_node_type = params['aws_node_type']

        msg_pair('AWS node type', aws_node_type)
        msg_pair('Initial Run List', env_data['initial_run_list'])
        msg_pair('Final Run List', params['run_list'])

        instance_data = bag_data['aws_node_types'][aws_node_type]

        server_creator = Chef::Knife::BolsterServerCreate.new
        server_creator.config[:chef_node_name]   = name
        server_creator.config[:run_list]         = params['run_list'].split(/,/)
        server_creator.config[:initial_run_list] = env_data['initial_run_list'].split(/,/)
        server_creator.config[:security_groups]  = instance_data["security_groups"].split(/,/)
        server_creator.config[:ssh_user]         = instance_data["ssh_user"]
        server_creator.config[:identity_file]    = instance_data["identity_file"]
        Chef::Config[:knife][:flavor]            = instance_data["flavor"]
        Chef::Config[:knife][:image]             = instance_data["image"]
        Chef::Config[:knife][:aws_ssh_key_id]    = instance_data["aws_ssh_key_id"]
        Chef::Config[:knife][:availability_zone] = instance_data["availability_zone"]

        server_creator.run

      end

      def run

        msg_pair("Loading Environment", config[:environment])
        load_environment(config[:environment])

        puts
        msg("=== Processing Topology")

        topology.each do |instance|
          name = instance['node_name']
          msg_pair('Node', name)
          # node = Chef::Node.load(name)
          node = find_nodes("name:#{name}")[0]

          if node
            msg("Node exists")
          else
            create_node(instance)
          end

          puts

        end

        msg("=== Final Chef Pass")

        topology.each do |instance|
          name = instance['node_name']
          node = Chef::Node.load(name)
          msg_pair('Node',node.name)

          msg_pair('  Old Run List',node.run_list)
          node.run_list = Chef::RunList.new(instance['run_list'])
          node.save
          msg_pair('  New Run List',node.run_list)

          msg_pair('  Environment',node.chef_environment)
          msg_pair('  Hostname', node['cloud']['public_hostname'] )
          run_chef(node)
          puts
        end

      end

    end
  end
end
