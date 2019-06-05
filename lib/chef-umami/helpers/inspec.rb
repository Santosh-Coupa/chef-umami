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
require 'json'
module Umami
  module Helper
    module InSpec
      # Call on a resource's #identity method to help describe the resource.
      # This saves us from having to know/code the identity attribute for each
      # resource (i.e. File is :path, User is :username, etc).
      def desciption(resource)
        identity = resource.identity
        if identity.is_a? Hash # #identity could return a Hash. Take the first value.
          identity = identity.values.first
        else
          identity = resource.identity
        end
        "describe #{resource.declared_type}('#{identity}') do"
      end

      # All test methods should follow the naming convention 'test_<resource type>'
      #  1. The methods should build up an array of lines defining the test.
      #  1. The first element should be the result of a call to
      #  #description(resource) except in cases where it is not appropriate
      #  (i.e. testing a directory resource requires defining a file test).
      #  2. The method should should return a string joined by newlines.
      #
      # def test_wutang(resource)
      #   test = [desciption(resource)]
      #   test << "it { should be_financially_sound }"
      #   test << "it { should be_diverisified }"
      #   test.join("\n")
      # end

      # InSpec can evaluate if a gem is installed via the system `gem` (default)
      # or via some other `gem` binary, defined by either the path to the gem
      # binary of a symbol representing that context.
      def test_gem_package(resource, gem_binary = nil)
        package_name = resource.package_name
        if !resource.gem_binary.nil? and !resource.gem_binary.empty?
          gem_binary = resource.gem_binary
          test = ["describe gem('#{package_name}', '#{gem_binary}') do"]
        elsif gem_binary
          if gem_binary.is_a? Symbol
            gem_binary = gem_binary.inspect # Stringify the symbol.
          else
            gem_binary = "'#{gem_binary}'"
          end
          test = ["describe gem('#{package_name}', '#{gem_binary}') do"]
        else
          test = ["describe gem('#{package_name}') do"]
        end
        test << 'it { should be_installed }'
        unless resource.version.nil?
          unless !resource.version.is_a?(String) && !resource.version.empty?
            if check_in_array(resource.action,:remove)
              test << "its('versions') { should_not include '#{resource.version}' }"
            else 
              test << "its('versions') { should include '#{resource.version}' }"
            end
          end
        end
        test << 'end'
        test.join("\n")
      end

      def test_chef_gem(resource)
        test_gem_package(resource, '/opt/chef/embedded/bin/chef')
      end

      def test_cron(resource)
        command = command.gsub(/'/,'\'')
        if resource.name =='Coupa Chef Client' or command.include? "coupa-utl::backup" or command.include? "coupa-db::do_backup"
          command = command.gsub( /--environment ([a-z]+[0-9]+)/,"--environment \#{coupah}")
          test = ["describe crontab('#{resource.user}') do"]
          test << "its('commands') { should include \"#{command}\"}"
        else
          command = command.gsub( /--environment ([a-z]+[0-9]+)/,"--environment \#{coupah}")
          z = "\""
          if command.include? z
            test = ["describe crontab('#{resource.user}').commands(\'#{command}\') do"] 
          else
            test = ["describe crontab('#{resource.user}').commands(\"#{command}\") do"] 
          end
          test << "its('minutes') { should cmp '#{resource.minute}' }"
          test << "its('hours') { should cmp '#{resource.hour}' }"
          test << "its('days') { should cmp '#{resource.day}' }"
          test << "its('weekdays') { should cmp '#{resource.weekday}' }"
          test << "its('months') { should cmp '#{resource.month}' }"
        end
        test << 'end'
        test.join("\n")
      end      

      def test_file(resource)
        file_exclude = ['/tmp/wazuh_kibana_installer.py']
        if !file_exclude.include? resource.path
          test = ["describe file('#{resource.path}') do"]
          ignor_file = ['/opt/rightscale/etc/motd-complete','/opt/rightscale/etc/motd-failed']
          unless ignor_file.include? resource.path or check_in_array(resource.action,:delete, check_include=true)
            if resource.resource_name =~ /directory/
              test << 'it { should be_directory }'
            else
              test << 'it { should be_file }'
            end
            # Sometimes we see GIDs instead of group names.
            unless resource.group.nil?
              unless resource.group.is_a?(String) && resource.group.empty?
                test << "it { should be_grouped_into '#{resource.group}' }"
              end
            end
            # Guard for UIDs versus usernames as well.
            unless resource.owner.nil?
              unless resource.owner.is_a?(String) && resource.owner.empty?
                test << "it { should be_owned_by '#{resource.owner}' }"
              end
            end
            unless resource.mode.nil?
              if resource.mode.is_a?(String)
                unless resource.mode.is_a?(Integer) && !resource.mode.empty?
                    cv = resource.mode.to_i(8)
                    test << "it { should be_mode #{cv} }"
                end
              else
                unless resource.mode.is_a?(String) && !resource.mode.empty?
                    test << "it { should be_mode #{resource.mode} }"
                end
              end
            end
          else
            test << "it { should_not exist }"
          end
          test << 'end'
        else
          test =[]
        end

        test.join("\n")
      end
      alias_method :test_cookbook_file, :test_file
      alias_method :test_directory, :test_file
      alias_method :test_remote_file, :test_file
      alias_method :test_remote_directory, :test_file
      alias_method :test_template, :test_file
      
      def test_group(resource)
        test = [desciption(resource)] 
        if !check_in_array(resource.action,:remove)
          test << 'it { should exist }'
        else
          test << "it { should_not exist }"
        end
        test << 'end'
        test.join("\n")
      end

      def test_package(resource)
        data  = JSON.parse(File.read(get_package_json_file))
        if data.keys.include? resource.package_name
          package_name = data[resource.package_name]['name']
          test = ["describe package('#{package_name}') do"]
        else
          test = [desciption(resource)]
        end

        if check_in_array(resource.action,:upgrade,true)
          test << "it { should be_installed }"
        elsif !check_in_array(resource.action,:remove)
          if !resource.version.nil? && !resource.version.empty?
            if data.keys.include? resource.package_name
              version = data[resource.package_name]['version']
            else
              version = resource.version
            end             
            test << "it { should be_installed }"
            test << "its('version') { should include '#{version}' }"
          else
            test << 'it { should be_installed }'
          end    
        else
            test << 'it { should_not be_installed }'
        end    
        test << 'end'
        test.join("\n")
      end

      def test_user(resource)
        test = [desciption(resource)]
        if !check_in_array(resource.action,:remove)
          test << 'it { should exist }'
          # Guard for GIDs rather than strings. Chef aliases the #group method
          # to the #gid method.
          unless resource.gid.nil?
            unless resource.gid.is_a?(String) && !resource.gid.empty?
              #test << "it { should belong_to_primary_group '#{resource.gid}' }"
              test << "its('gid') { should eq #{resource.gid}}"
            end
          end

          unless resource.uid.nil?
            unless resource.uid.is_a?(String) && !resource.uid.empty?
              test << "its('uid') { should eq #{resource.uid}}"
            end
          end
            
          unless resource.group.nil?
            if resource.gid.nil? or resource.group != resource.gid 
               unless resource.group.is_a?(Integer) && !resource.group.empty?
                 test << "its('group') { should eq '#{resource.group}'}"
               end
            end
          end 

          if !resource.home.nil? && !resource.home.empty?
            #test << "it { should have_home_directory '#{resource.home}' }"
            test << "its('home') { should eq '#{resource.home}' }"
          end

          #if !resource.groups.nil? && !resource.groups.empty?
          #  test << "its('groups') { should eq #{resource.groups}"
          #end  
          if !resource.shell.nil? && !resource.shell.empty?
            test << "its('shell') { should eq '#{resource.shell}'}"
          end
        else
           test << "it { should_not exist }"
        end			
        test << 'end'
        test.join("\n")
      end



      def test_yum_package(resource)
        test = ["describe package('#{resource.package_name}') do"]
        test << 'it { should be_installed }'
        test << 'end'
        test.join("\n")
      end
      
      def test_sysctl_param(resource)
        test = ["describe kernel_parameter('#{resource.name}') do"]
        test << "its('value') { should eq #{resource.value} }"
        test << 'end'
        test.join("\n")
      end
      
      def test_service(resource)
        test = ["describe service('#{resource.name}') do"]
        if !resource.ignore_failure
          if check_in_array(resource.action,:stop)
            test << "it { should_not be_running }"
          end

          if check_in_array(resource.action,:disable)
            test << "it {should_not be_enabled}" 
          end

          if check_in_array(resource.action,:start,check_include=true)
            #test << "it { should be_installed }"
            test << "it { should be_running }"
          end

          if check_in_array(resource.action,:restart,check_include=true)
            #test << "it { should be_installed }"
            test << "it { should be_running }"
          end

          if check_in_array(resource.action,:enable,check_include=true)
            #test << "it { should be_installed }"
            test << "it {should be_enabled}"
          end
        end
        test << 'end'
        test.join("\n")
      end
      
      #def test_users_manage(resource)
      #  puts "#test bash missing"
      #end
  
      #def test_execute(resource)
      #  binding.pry
      #  puts "#test execute missing"
      #end 
      def test_link(resource)
        if !resource.to.include? "/mnt/ephemeral"
          target = resource.to.gsub(/\/home/, "/mnt/ephemeral/home")
          target = target.gsub(/\/etc\/coupa/, "/mnt/ephemeral/etc/coupa")
          target = target.gsub(/\/usr\/local\/coupa/, "/mnt/ephemeral/usr/local/coupa")
          target = target.gsub(/ca-bundle.crt/, "ca-bundle-complete.crt")
          target = target.gsub(/\/opt\/rbenv/, "/opt/rbenv-0.4.0")
        else
          target = resource.to.gsub(/ca-bundle.crt/, "ca-bundle-complete.crt")
        end
     
        #/etc/coupa -> /mnt/ephemeral/etc/coupa
        test = ["describe file('#{resource.name}') do"]
        test << "it { should be_symlink }"
        test << "it { should be_linked_to '#{target}' }"
        test << 'end'
        test.join("\n")
      end

      def check_in_array(action,inc_string, check_include=false)
        if action.is_a? Array
          if check_include
            return action.include? inc_string
          else
            return action[-1] == inc_string
          end
        elsif action.is_a? Symbol
          return action == inc_string
        else
          return false
        end
      end
      def get_package_json_file
        spec = Gem::Specification.find_by_name("chef-umami")
        gem_root = spec.gem_dir
        gem_root + '/lib/chef-umami/helpers/packages.json'
      end
    end
  end
end
