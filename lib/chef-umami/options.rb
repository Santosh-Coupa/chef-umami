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

require 'chef-umami/version'

module Umami
  module Options
    # Parse command line options. Returns hash of options.
    def parse_options
      options = {}
      # Default options
      options[:integration_tests] = true
      options[:policyfile] = 'Policyfile.rb'
      options[:test_root] = 'spec'
      options[:unit_tests] = true
      options[:cookbooks_dir] = '/var/chef/cache/cookbooks/coupa-*'
      parser = OptionParser.new do |opts|
        opts.banner = opts.banner + "\n\nA taste you won't forget!\n\n"
        opts.on('-h', '--help', 'Prints this help message') {
          puts opts
          exit
        }
        opts.on('-i', '--[no-]integration-tests', 'Write integration tests' \
                " (DEFAULT: #{options[:integration_tests]})") do |integration_tests|
          options[:integration_tests] = integration_tests
        end
        #opts.on('-p', '--policyfile POLICYFILE_PATH', 'Specify the path to a policy' \
        #        " (DEFAULT: #{options[:policyfile]})") do |policyfile|
        #  options[:policyfile] = policyfile
        #end
        opts.on('-r', '--recipes RECIPE1,RECIPE2', Array,
                "Specify one or more recipes for which we'll write tests" \
                ' (DEFAULT: All recipes)') do |recipes|
          options[:recipes] = recipes
          options[:all_supported_cookbooks] = []
          if options[:recipes][0] == 'all'
             options[:recipes] = get_all_recipies_list
             puts " Generating Unit and Integration tests on following recipies"
             puts "#{options[:recipes]}"
          end
        end
        opts.on('-t', '--test-root TEST_ROOT_PATH', "Specify the path into which we'll write tests" \
                " (DEFAULT: #{options[:test_root]})") do |test_root|
          options[:test_root] = test_root
        end
        opts.on('-u', '--[no-]unit-tests', 'Write unit tests' \
                " (DEFAULT: #{options[:unit_tests]})") do |unit_tests|
          options[:unit_tests] = unit_tests
        end

        opts.on('-n', '--name-recipe NAMERECIPE', 'Specify name recpie' \
                " (DEFAULT: #{options[:name_recipes]})") do |name_recipe|
          options[:name_recipes] = name_recipe
          options[:recipes] = name_recipe
        end


        opts.on('-a', '--all-supported-cookbooks SUPPORTED_COOKBOOKS', 'Provide true and false' \
                " (DEFAULT: #{options[:all_supported_cookbooks]})") do |supported_cookbooks|
          options[:all_supported_cookbooks] = supported_cookbooks
           options[:recipes] = []
        end

        opts.on('-c', '--cookbook-dir COOKBOOKS_DIR', 'Cookbook dir to execute' \
                " (DEFAULT: #{options[:cookbooks_dir]})") do |dir|
          options[:cookbooks_dir] = dir
        end

        opts.on('-v', '--version', 'Show version and exit') {
          puts "chef-umami v#{Umami::VERSION}"
          exit
        }
      end
      begin
        parser.parse!
      rescue OptionParser::InvalidOption => e
        puts "Warning: #{e.message}"
        if e.message =~ /--pattern/
          puts 'Ah, this is likely parsed from `rspec` options. We can safely ignore this.'
      end
        puts 'Ignoring the option.'
      end
      options
    end

    def get_all_recipies_list
      cookbook = Dir.pwd.split('/')[-1]
      recpies_list = []
      Dir["recipes/*.rb"].each do |r|
        recip = cookbook + "::" + r.split('/')[1].split('.')[0]
        recpies_list.push(recip)
      end
      return recpies_list
    end
  end
end