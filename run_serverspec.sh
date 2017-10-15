#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2017 DennyZhang.com
## Licensed under MIT 
##   https://www.dennyzhang.com/wp-content/mit_license.txt
##
## File : run_serverspec.sh
## Author : Denny <contact@dennyzhang.com>
## Description :
## --
## Created : <2017-05-14>
## Updated: Time-stamp: <2017-09-07 21:35:14>
##-------------------------------------------------------------------
function setup_serverspec() {
    working_dir=${1?}
    cd "$working_dir"
    if [ ! -f spec/spec_helper.rb ]; then
        echo "Setup Serverspec Test case"
        cat > spec/spec_helper.rb <<EOF
require 'serverspec'

set :backend, :exec
EOF

        cat > Rakefile <<EOF
require 'rake'
require 'rspec/core/rake_task'

task :spec => 'spec:all'
task :default => :spec

namespace :spec do
 targets = []
 Dir.glob('./spec/*').each do |dir|
 next unless File.directory?(dir)
 target = File.basename(dir)
 target = "_#{target}" if target == "default"
 targets << target
 end

 task :all => targets
 task :default => :all

 targets.each do |target|
 original_target = target == "_default" ? target[1..-1] : target
 desc "Run serverspec tests to #{original_target}"
 RSpec::Core::RakeTask.new(target.to_sym) do |t|
 ENV['TARGET_HOST'] = original_target
 t.pattern = "spec/#{original_target}/*_spec.rb"
 end
 end
end
EOF
    fi
}

if [ -z "$flag_file" ]; then
    flag_file="$HOME/$JOB_NAME.flag"
fi

function shell_exit() {
    errcode=$?
    if [ $errcode -eq 0 ]; then
        echo "OK" > "$flag_file"
    else
        echo "ERROR" > "$flag_file"
    fi
    exit $errcode
}

trap shell_exit SIGHUP SIGINT SIGTERM 0

[ -n "$working_dir" ] || working_dir="$HOME/$JOB_NAME"

mkdir -p "$working_dir/spec/localhost"
cd "$working_dir"

# sudo /usr/sbin/locale-gen --lang en_US.UTF-8
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

setup_serverspec "$working_dir"

cat > spec/localhost/sample_spec.rb <<EOF
require 'spec_helper'

# Check at least 2 GB free disk
describe command("[ $(df -h / | tail -n1 |awk -F' ' '{print $4}' | awk -F'G' '{print $1}' | awk -F'.' '{print $1}') -gt 2 ]") do
  its(:exit_status) { should eq 0 }
end

$test_spec
EOF

echo "Perform serverspec check: $working_dir/spec/localhost/sample_spec.rb"
rake spec -v
## File : run_serverspec.sh ends
