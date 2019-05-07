#!/opt/chef/embedded/bin/ruby -w

def get_ruby_path
  chefv = `chef-client -v`
  if chefv.include?'Chef: 11.18.6'
     return '/opt/ruby-2.3.1/bin/umami'
  else
     return '/opt/chef/embedded/bin/umami'
  end
end

def get_all_recipies_list
  fail_flag = true
  directory = "Build_unit_test"
  Dir.mkdir(directory) unless File.exist?(directory)
  Dir.glob("/var/chef/cache/cookbooks/coupa-*").each do |r|
    if Dir.exist? r
      cookbook = r.split('/')[-1]
      puts "Genrating Unit and integration test cases for cookbook #{cookbook}"
      if system("cd #{directory} && sudo rm -rf #{cookbook}")
        status = system("cd #{directory} && git clone git@github.com:coupa-ops/#{cookbook}.git")
        if status
           if system("cd #{directory}/#{cookbook} && sudo #{get_ruby_path} -r all")
              puts "Unit and integration test cases generated for cookbook #{cookbook}"
           else
              puts "Unit and integration test cases generation failed for cookbook #{cookbook}"
              fail_flag = false
           end
        else
           puts "Git clone failed for  cookbook #{cookbook}"
           fail_flag = false
        end
      else
         puts "Delete directory failed for  cookbook #{cookbook}"
         fail_flag = false
      end
    end
  end
  return fail_flag
end

if get_all_recipies_list
  cookbook_dir = Dir.pwd
  puts "#{cookbook_dir}/Build_unit_test"
else
  raise("Failed to execute script")
end
