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
require 'chef-umami/helpers/inspec'
require 'chef-umami/helpers/filetools'
require 'pry'

module Umami
  class Test
    class Integration < Umami::Test
      include Umami::Helper::InSpec
      include Umami::Helper::FileTools

      attr_reader :test_root
      def initialize(root_dir)
        super
        servertype = get_server_details
        @test_root = File.join(self.root_dir, 'umami',servertype)
      end

      # InSpec doesn't need a require statement to use its tests.
      # We define #framework here for completeness.
      def framework
        'inspec'
      end

      def test_file_path(cookbook = '', recipe = '')
        #servertype = get_server_details
        "#{test_root}/#{cookbook}/integration/#{cookbook}_#{recipe}_spec.rb"
      end

      def preamble(cookbook = '', recipe = '')
        "# #{test_file_path(cookbook, recipe)} - Originally written by Umami! \n def coupahost \n\s\s\shost = `hostname`.strip\n\s\s\s host.split('.')[0].gsub(/([a-z]+)([0-9]+).*/,'\\1\\2')\nend\ncoupah=coupahost"
      end

      # Call on the apprpriate method from the Umami::Helper::InSpec
      # module to generate our test.
      def write_test(resource = nil)
        if resource.action.is_a? Array
          return if resource.action.include?(:delete)
        end
        return if resource.action == :delete
        "\n" + send("test_#{resource.declared_type}", resource)
      end

      # If the test framework's helper module doesn't provide support for a
      # given test-related method, return a friendly message.
      # Raise NoMethodError for any other failed calls.
      def method_missing(meth, *args, &block)
        case meth
        when /^test_/
          "# #{meth} is not currently defined. Stay tuned for updates."
        else
          raise NoMethodError
        end
      end

      def generate(recipe_resources = {})
        test_files_written = []
        recipe_resources.each do |canonical_recipe, resources|
          (cookbook, recipe) = canonical_recipe.split('::')
          content = [preamble(cookbook, recipe)]
          resources.each do |resource|
            next unless check_valid_resource(resource)
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
          test_file_name = test_file_path(cookbook, recipe)
          test_file_content = content.join("\n") + "\n"
          write_file(test_file_name, test_file_content)
          test_files_written << test_file_name
        end
        enforce_styling(test_root)

        unless test_files_written.empty?
          puts 'Wrote the following integration tests:'
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

      def check_valid_resource(resource)
        host = `hostname`.strip
        domain = host.split('.')[-2]+ '.' + host.split('.')[-1]
        res = [:cookbook_file,:directory,:remote_file,:remote_directory,:template,:file]
        if res.include? resource.resource_name
          if !resource.path.include? domain
            return true
          else
            return false
          end
        else
          return true
        end
      end  
    end
  end
end
