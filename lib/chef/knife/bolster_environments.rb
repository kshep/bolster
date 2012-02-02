require 'chef/knife/bolster_base'
require 'chef/data_bag_item'
require 'ruby-debug'

class Chef
  class Knife
    class BolsterEnvironments < Knife

      include Knife::BolsterBase

      deps do
        require 'chef/knife/ssh'
        Chef::Knife::Ssh.load_deps
      end

      banner "knife bolster environments"

      def run

        # Get the list of environments
        Chef::Environment.list.each do |e|
          msg_pair("=== Environment",e[0])
          load_environment(e)
          puts
          output(format_for_display(env_data))
          puts
        end

      end

    end
  end
end
