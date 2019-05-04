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
          test = ["describe gem('#{package_name}', #{gem_binary}) do"]
        elsif gem_binary
          if gem_binary.is_a? Symbol
            gem_binary = gem_binary.inspect # Stringify the symbol.
          else
            gem_binary = "'#{gem_binary}'"
          end
          #test = ["#Gem '#{package_name}' is installed via the #{gem_binary} gem"]
          test = ["describe gem('#{package_name}', #{gem_binary}) do"]
        else
          #test = ["#Gem '#{package_name}' is installed via the #{gem_binary} gem"]
          test = ["describe gem('#{package_name}') do"]
        end
        test << 'it { should be_installed }'
        unless resource.version.nil?
            unless !resource.version.is_a?(String) && !resource.version.empty?
              ver = resource.version.split('.')
              if ver[-1] == 0
                res_ver = ver[0..-2].join('.')
              else
                res_ver = resource.version
              end
              #test << "it { should belong_to_primary_group '#{resource.gid}' }"
              test << "its('version') { should include /#{res_ver}/ }"
            end
          end
        test << 'end'
        test.join("\n")
      end

      def test_chef_gem(resource)
        test_gem_package(resource, ':chef')
      end

      def test_cron(resource)
        test = ["describe crontab('#{resource.user}').commands('#{resource.command}') do"]
        test << "its('minutes') { should cmp '#{resource.minute}' }"
        test << "its('hours') { should cmp '#{resource.hour}' }"
        test << "its('days') { should cmp '#{resource.day}' }"
        test << "its('weekdays') { should cmp '#{resource.weekday}' }"
        test << "its('month') { should cmp '#{resource.month}' }"
        test << 'end'
        test.join("\n")
      end

      def test_file(resource)
        test = ["describe file('#{resource.path}') do"]
        if resource.declared_type =~ /directory/
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
        test << 'end'
        test.join("\n")
      end
      alias_method :test_cookbook_file, :test_file
      alias_method :test_directory, :test_file
      alias_method :test_remote_file, :test_file
      alias_method :test_remote_directory, :test_file
      alias_method :test_template, :test_file

      def test_group(resource)
        test = [desciption(resource)]
        if !resource.action.include? :remove
          test << 'it { should exist }'
        else
          test << "it { should_not exist }"
        end
        test << 'end'
        test.join("\n")
      end

      def test_package(resource)
        test = [desciption(resource)]
        if !resource.action.include? :remove
          if !resource.version.nil? && !resource.version.empty?
            test << "it { should be_installed }"
            test << "its('version') { should include '#{resource.version}' }"
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
        if !resource.action.include? :remove
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
              #test << "it { should belong_to_primary_group '#{resource.gid}' }"
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
        test << "it { should be_installed }"
        if resource.action.include(:start) 
          test << "it { should be_running }"
        end
        if resource.action.include(:enable)
          test << "it {should be_enabled}"
        end
        test << 'end'
        test.join("\n")
      end

      def test_link(resource)
        test = ["describe file('#{resource.name}') do"]
        test << "it { should be_symlink }"
        test << "it { should be_linked_to '#{resource.to}' }"
        test << 'end'
        test.join("\n")
      end
    end
  end
end
