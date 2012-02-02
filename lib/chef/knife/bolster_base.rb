require 'chef/knife'

class Chef
  class Knife
    module BolsterBase

      def self.included(includer)
        includer.class_eval do

          deps do
            require 'readline'
            require 'chef/json_compat'
          end

          option :environment,
            :short => "-e ENVIRONMENT",
            :long => "--environment ENVIRONMENT",
            :description => "The Chef Server environment to bolster",
            :proc => Proc.new { |key| Chef::Config[:knife][:environment] = key },
            :default => "_default"

        end
      end

      def msg(value, color=:cyan)
        puts "#{ui.color(value, color)}"
      end

      def msg_pair(label, value, color=:cyan)
        if value && !value.to_s.empty?
          puts "#{ui.color(label, color)}: #{value}"
        end
      end

      def locate_config_value(key)
        key = key.to_sym
        Chef::Config[:knife][key] || config[key]
      end

      def load_environment(env)
        Chef::Config[:bolster] = {}
        Chef::Config[:bolster][:env_name] = env.kind_of?(Array) ? env[0] : env

        Chef::Config[:bolster][:env_data] = Chef::Environment.load(env_name).default_attributes
        env_data = Chef::Config[:bolster][:env_data]
        if env_data['config_data']
          bag = env_data['config_data']['bag']
          item = env_data['config_data']['item']
          Chef::Config[:bolster][:bag_data] ||= Chef::DataBagItem.load(bag, item).raw_data
        end
      end

      def env_name
        return Chef::Config[:bolster][:env_name]
      end

      def env_data
        return Chef::Config[:bolster][:env_data]
      end

      def bag_data
        return Chef::Config[:bolster][:bag_data]
      end

      def topology
        return Chef::Config[:bolster][:env_data]['topology'] || []
      end

      def tcp_test_ssh(hostname)
        tcp_socket = TCPSocket.new(hostname, 22)
        readable = IO.select([tcp_socket], nil, nil, 5)
        if readable
          Chef::Log.debug("sshd accepting connections on #{hostname}, banner is #{tcp_socket.gets}")
          yield
          true
        else
          false
        end
      rescue SocketError
        sleep 2
        false
      rescue Errno::ETIMEDOUT
        false
      rescue Errno::EPERM
        false
      rescue Errno::ECONNREFUSED
        sleep 2
        false
      # This happens on EC2 quite often
      rescue Errno::EHOSTUNREACH
        sleep 2
        false
      ensure
        tcp_socket && tcp_socket.close
      end

      def find_nodes(query)
        #
        #  environment : corresponds to the node.chef_environment
        #  query       : like "ec2:*" or "role:base"
        #
        q = Chef::Search::Query.new
        s = "#{query} AND chef_environment:#{env_name}"
        return q.search('node',s)[0]
      end

      def run_chef(node)
        name = node.name
        msg_pair("  Running Chef on", name)
        knife_ssh = Chef::Knife::Ssh.new()
        knife_ssh.config[:attribute] = 'ec2.public_hostname'
        knife_ssh.config[:ssh_user] = 'ubuntu'
        knife_ssh.name_args = ["name:"+name,"sudo chef-client"]
        knife_ssh.run
      end

      def connection
        @connection ||= begin
          connection = Fog::Compute.new(
            :provider => 'AWS',
            :aws_access_key_id => Chef::Config[:knife][:aws_access_key_id],
            :aws_secret_access_key => Chef::Config[:knife][:aws_secret_access_key],
            :region => locate_config_value(:region)
          )
        end
      end

      def validate!(keys=[:aws_access_key_id, :aws_secret_access_key])
        errors = []

        keys.each do |k|
          pretty_key = k.to_s.gsub(/_/, ' ').gsub(/\w+/){ |w| (w =~ /(ssh)|(aws)/i) ? w.upcase  : w.capitalize }
          if Chef::Config[:knife][k].nil?
            errors << "You did not provided a valid '#{pretty_key}' value."
          end
        end

        if errors.each{|e| ui.error(e)}.any?
          exit 1
        end
      end

      #--------------------------------------------------------------------------------
      # Other ways to access Chef server data...
      #--------------------------------------------------------------------------------
      #
      # Get the list of all nodes
      #
      #   output(format_for_display(Chef::Node.list))
      #
      # Get the list of nodes including all their data
      #
      #   output(format_for_display(Chef::Node.list(true)))
      #
      # Get the list of roles
      #
      #   output(format_for_display(Chef::Role.list))
      #
      # Get the list of data bags
      #
      #   output(format_for_display(Chef::DataBag.list))
      #


    end
  end
end
