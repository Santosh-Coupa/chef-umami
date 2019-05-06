#   Copyright 2017 Bloomberg Finance, L.P.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

require 'chef'
require 'chef-umami/exceptions'
require 'chef-umami/client'
require 'chef-umami/logger'
require 'chef-umami/options'
require 'chef-umami/server'
#require 'chef-umami/policyfile/exporter'
#require 'chef-umami/policyfile/uploader'
require 'chef-umami/test/unit'
require 'chef-umami/test/integration'

module Umami
  class Runner
    include Umami::Logger
    include Umami::Options

    attr_reader :cookbook_dir
    def initialize
      @config = config
      @cookbook_dir = Dir.pwd
      #@exporter = exporter
      @chef_zero_server = chef_zero_server
      # If we load the uploader or client now, they won't see the updated
      # Chef config!
      @uploader = nil
      @chef_client = nil
    end

    # A hash of values describing the config. Comprised of command line
    # options. May (in the future) contain options read from a config file.
    def config
      @config ||= parse_options
    end

    def policyfile
      config[:policyfile]
    end

    # Return the computed policyfile lock name.
    def policyfile_lock_file
      policyfile.gsub(/\.rb$/, '.lock.json')
    end

    def validate_lock_file!
      unless policyfile_lock_file.end_with?('lock.json')
        raise InvalidPolicyfileLockFilename, "Policyfile lock files must end in '.lock.json'. I received '#{policyfile_lock_file}'."
      end

      unless File.exist?(policyfile_lock_file)
        raise InvalidPolicyfileLockFilename, "Unable to locate '#{policyfile_lock_file}' You may need to run `chef install` to generate it."
      end
    end

    #def exporter
    #  @exporter ||= Umami::Policyfile::Exporter.new(policyfile_lock_file, cookbook_dir, policyfile)
    #end

    def uploader
      @uploader ||= Umami::Policyfile::Uploader.new(policyfile_lock_file)
    end

    def chef_zero_server
      @chef_zero_server ||= Umami::Server.new
    end

    def chef_client
      @chef_client ||= Umami::Client.new
    end

    def get_all_recipies_list
      cookbook = Dir.pwd.split('/')[-1]
      recpies_list = []
      Dir["recipes/*.rb"].each do |r|
        recip = cookbook + "::" + r.split('/')[1].split('.')[0]
        recpies_list.append recpies_list
      end
      return recpies_list
    end  

    def run
      #validate_lock_file!
      puts "\nExporting the policy, related cookbooks, and a valid client configuration..."
      #FileUtils.cp(config[:json_config], '/tmp/config.json')
      #exporter.export
      #file_names = [exporter.chef_config_file]
      #file_names.each do |file_name|
      #   text = File.read(file_name)
      #   new_contents = text.gsub(/policy_group 'local'/, "policy_group 'dev'")
      #  # To merely print the contents of the file, use:
      #  puts new_contents

      #  # To write changes to the file, use:
      #  File.open(file_name, "w") {|file| file.puts new_contents }
      #end
      Chef::Config.from_file('/etc/chef/client.rb')
      #Chef::Config['policy_group'] ='dev'
      #chef_zero_server.start
      puts "\nUploading the policy and related cookbooks..."
      #uploader.upload
      puts "\nExecuting chef-client compile phase..."
      # Define Chef::Config['config_file'] lest Ohai complain.
      Chef::Config['config_file'] = '/etc/chef/client.rb' 
      sleep 60
      chef_client.compile
      # Build a hash of all the recipes' resources, keyed by the canonical
      # name of the recipe (i.e. ohai::default).
      recipe_resources = {}
      if config[:recipes].empty?
        config[:recipes] = get_all_recipies_list
        
      chef_client.resource_collection.each do |resource|
        canonical_recipe = "#{resource.cookbook_name}::#{resource.recipe_name}"
        unless config[:recipes].empty?
          # The user has explicitly requested that one or more recipes have
          # tests written, to the exclusion of others.
          # ONLY include the recipe if it matches the list.
          next unless config[:recipes].include?(canonical_recipe)
        end
        if recipe_resources.key?(canonical_recipe)
          recipe_resources[canonical_recipe] << resource
        else
          recipe_resources[canonical_recipe] = [resource]
        end
      end

      # Remove the temporary directory using a naive guard to ensure we're
      # deleting what we expect.
      #re_export_path = Regexp.new('/tmp/umami')
      #FileUtils.rm_rf(exporter.export_root) if exporter.export_root.match(re_export_path)

      if config[:unit_tests]
        puts "\nGenerating a set of unit tests..."
        unit_tester = Umami::Test::Unit.new(config[:test_root])
        unit_tester.generate(recipe_resources)
      end

      if config[:integration_tests]
        puts "\nGenerating a set of integration tests..."
        integration_tester = Umami::Test::Integration.new(config[:test_root])
        integration_tester.generate(recipe_resources)
      end
    end
  end
end
