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

require 'chef-umami/test'
require 'chef-umami/helpers/os'
require 'chef-umami/helpers/filetools'
require 'pry'

module Umami
  class Test
    class Unit < Umami::Test
      include Umami::Helper::OS
      include Umami::Helper::FileTools

      attr_reader :test_root
      attr_reader :tested_cookbook # This cookbook.
      def initialize(root_dir)
        super
        servertype = get_server_details
        @test_root = File.join(self.root_dir, 'umami',servertype)
        @tested_cookbook = File.basename(Dir.pwd)
      end

      def framework
        'chefspec'
      end

      def test_file(cookbook = '',recipe = '')
        servertype = get_server_details
        "#{test_root}/#{cookbook}/unit/#{recipe}_spec.rb"
      end

      def spec_helper_path
        File.join(test_root, '..', 'spec_helper.rb')
      end

      def preamble(cookbook = '', recipe = '')
        "# #{test_file(recipe)} - Originally written by Umami!\n" \
        "\n" \
        "require_relative '../spec_helper'\n" \
        "\n" \
        "describe '#{cookbook}::#{recipe}' do\n" \
        "let(:chef_run) { ChefSpec::ServerRunner.new(platform: '#{os[:platform]}').converge(described_recipe) }"
      end

      def write_spec_helper
        content = ["require '#{framework}'"]
        content << "require '#{framework}/policyfile'"
        content << "at_exit { ChefSpec::Coverage.report! }\n"
        write_file(spec_helper_path, content.join("\n"))
      end

      def write_test(resource = nil)
        state_attrs = [] # Attribute hash to be used with #with()
        resource.state_for_resource_reporter.each do |attr, value|
          next if value.nil? || (value.respond_to?(:empty) && value.empty?)
          if value.is_a? String
            value = value.gsub("'", "\\\\'") # Escape any single quotes in the value.
          end
          if attr == :variables
            state_attrs << "#{attr}: #{value}"
          elsif[true, false].include? value
            state_attrs << "#{attr}: #{value}"
          else
            state_attrs << "#{attr}: '#{value}'"
          end
        end
        action = ''
        if resource.action.is_a? Array
          action = resource.action.first
        else
          action = resource.action
        end
        resource_name = resource.name.gsub("'", "\\\\'") # Escape any single quotes in the resource name.
        test_output = ["\nit '#{action}s #{resource.declared_type} \"#{resource_name}\"' do"]
        if state_attrs.empty?
          test_output << "expect(chef_run).to #{action}_#{resource.declared_type}('#{resource_name}')"
        else
          test_output << "expect(chef_run).to #{action}_#{resource.declared_type}('#{resource_name}').with(#{state_attrs.join(', ')})"
        end
        test_output << "end\n"
        test_output.join("\n")
      end

      def generate(recipe_resources = {})
        test_files_written = []
        recipe_resources.each do |canonical_recipe, resources|
          (cookbook, recipe) = canonical_recipe.split('::')
          # Only write unit tests for the cookbook we're in.
          next unless cookbook == tested_cookbook
          content = [preamble(cookbook, recipe)]
          resources.each do |resource|
            if !resource.only_if.empty?
               if resource.only_if[0].continue?
                 content << write_test(resource)
               end
            elsif !resource.not_if.empty?
               if resource.not_if[0].continue?
                  content << write_test(resource)
               end
            else
               content << write_test(resource)
            end
          end
          content << 'end'
          test_file_name = test_file(cookbook,recipe)
          test_file_content = content.join("\n") + "\n"
          write_file(test_file_name, test_file_content)
          test_files_written << test_file_name
        end
        enforce_styling(test_root)
        write_spec_helper
        test_files_written << spec_helper_path

        unless test_files_written.empty?
          puts 'Wrote the following unit test files:'
          test_files_written.each do |f|
            puts "\t#{f}"
          end
        end
      end

      def get_server_details()
        host = `hostname`.strip
        if host.include? 'utl'
          servertype = host.split('.')[0].gsub(/([a-z]+)([0-9]+)([a-z]+)([0-9]+)/,'\1\3\4')  
        else
          servertype = host.split('.')[0].gsub(/[0-9]|srv/,"")
        end
        return servertype
      end
    end
  end
end
