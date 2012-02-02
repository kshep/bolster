# Knife Bolster


## Description

Bolster is a Knife plugin that makes it easy to provision, deploy to, and manage EC2-based clusters and environments.

It borrows heavily from the Opscode EC2 Knife plugin (http://github.com/opscode/knife-ec2) but it's intended to simplify
common tasks performed on pre-defined clusters of machines. While knife-ec2 provides basic functionality to create, destroy,
and modify individual nodes, bolster lets you operate on entire environments with single commands.

Bolster relies on Chef Server as a central data store and local files (ideally managed by version control) that
specify how each cluster or environment should be configured. Initial provisioning of an environment and subsequent
changes are performed simply by updating your configuration files and running the appropriate bolster command.


## Installation

Be sure you have the latest version of Chef (Bolster was initially developed with 0.10.5)

    gem install chef

The plugin is distrubuted as a Ruby Gem. To install it run:

    gem install knife-bolster

If you'd like to work from source and you happen to be using Bundler, you can clone the project and simply add...

    gem 'knife-bolster', :path => '/wherever/you/put/the/repository/knife-bolster'

...to you Gemfile and peform a 'bundle install'.

[TODO: knife-bolster depends on several other gems you'll need to list in your Gemfile. Put a pointer to that list here.]


## Configuration

If you're already using the Opscode knife-ec2 plugin, you're already done the basic configuration necessary. If not, you'll
need to place your AWS credentials in your knife.rb file:

    knife[:aws_access_key_id]  = "Your AWS Access Key ID"
    knife[:aws_secret_access_key] = "Your AWS Secret Access Key"

If your knife.rb file is in version control, it's probably a good idea to set these credentials via environment variables
you set elsewhere:

    knife[:aws_access_key_id] = "#{ENV['AWS_ACCESS_KEY_ID']}"
    knife[:aws_secret_access_key] = "#{ENV['AWS_SECRET_ACCESS_KEY']}"

## Subcommands

### knife bolster status

Displays everything bolster knows about your current environments and running instances

### knife bolster provision

Provisions a specified environment

### knife bolster deploy

Deploys to a specified environment

## knife-ec2 Note and Acknowledgement

If you've explored the Opscode knife-ec2 plugin source at all, much of the bolster source will look a little familiar.
Bolster uses the same general structure, Mixlib::CLI library, fog, and performs many of the same tasks knife-ec2 does.
However, it does so based on configuration information stored in files, rather than provided from the command line.
This means it's a bit difficult to call knife-ec2 methods directly, as they're doing quite a bit of command line input
validation, output, and generally don't tend to return values (e.g. the server objects corresponding to the instances
they create). So Bolster isn't a fork of knife-ec2, exactly, but it does a lot of the same things in the same way.
