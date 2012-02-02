require 'chef/knife/bolster_base'
require 'chef/data_bag_item'
require 'ruby-debug'

class Chef
  class Knife
    class BolsterStatus < Knife

      include Knife::BolsterBase

      deps do
        require 'fog'
        require 'readline'
        require 'chef/json_compat'
        require 'chef/knife/bootstrap'
        require 'chef/knife/ssh'
        require 'chef/node'
        Chef::Knife::Ssh.load_deps
        Chef::Knife::Bootstrap.load_deps
      end

      banner "knife bolster status (options)"

      def run

        msg_pair("Loading Environment", config[:environment])
        load_environment(config[:environment])

        msg("=== Environment Data")
        output(format_for_display(env_data))
        puts

        msg("=== Configuration Data")
        output(format_for_display(bag_data))
        puts

        msg("=== Topology")
        output(format_for_display(topology))
        puts

        msg("=== Nodes")

        topology.each do |instance|
          name = instance['node_name']
          msg_pair('Name', name)

          node_list = find_nodes("name:#{name}")
          if node_list.length > 1
            msg_pair("DUPLICATE NODES",node_list.join(','))
          else
            node = node_list[0]

            if node
              fqdn = node['cloud']['public_hostname']
              internal_hostname = node['cloud']['local_hostname']
              msg_pair("  Hostname", "#{fqdn} (#{internal_hostname})")
              if tcp_test_ssh(fqdn) {}
                msg("  Host is Up")
              else
                msg("  Failed to Connect")
              end
            else
              msg("  NOT FOUND")
            end

            puts
          end

        end

      end

    end
  end
end
