require 'chef/knife'

module Bolster

  class Cap < Chef::Knife

    deps do
      require 'capistrano'
      require 'capistrano/cli'
      require 'chef/search/query'
    end

    banner "knife cap ARGUMENTS"

    def run

      ARGV.shift
      Capistrano::CLI.execute

    end

  end
end

