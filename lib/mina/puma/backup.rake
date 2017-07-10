require 'mina/bundler'
require 'mina/rails'

namespace :puma do
  set :web_server, :puma

  set_default :puma_role,      -> { user }
  set_default :puma_env,       -> { fetch(:rails_env, 'production') }
  set_default :puma_config,    -> { "#{deploy_to}/#{shared_path}/config/puma.rb" }
  set_default :puma_socket,    -> { "#{deploy_to}/#{shared_path}/tmp/sockets/puma.sock" }
  set_default :puma_state,     -> { "#{deploy_to}/#{shared_path}/tmp/sockets/puma.state" }
  set_default :puma_pid,       -> { "#{deploy_to}/#{shared_path}/tmp/pids/puma.pid" }
  set_default :puma_cmd,       -> { "#{bundle_prefix} puma" }
  set_default :pumactl_cmd,    -> { "#{bundle_prefix} pumactl" }
  set_default :pumactl_socket, -> { "#{deploy_to}/#{shared_path}/tmp/sockets/pumactl.sock" }
  set_default :puma_root_path, -> { fetch(:current_path) }

  desc 'Start puma'
  task :start => :environment do
    puma_port_option = "-p #{puma_port}" if puma_port

    queue! %[
      if [ -e '#{pumactl_socket}' ]; then
        echo 'Puma is already running!';
      else
        if [ -e '#{puma_config}' ]; then
          cd #{deploy_to}/#{current_path} && #{puma_cmd} -q -d -e #{puma_env} -C #{puma_config}
        else
          cd #{deploy_to}/#{current_path} && #{puma_cmd} -q -d -e #{puma_env} -b 'unix://#{puma_socket}' #{puma_port_option} -S #{puma_state} --pidfile #{puma_pid} --control 'unix://#{pumactl_socket}'
        fi
      fi
    ]
  end

  desc 'Stop puma'
  task stop: :environment do
    pumactl_command 'stop'
    queue! %[rm -f '#{pumactl_socket}']
  end

  desc 'Restart puma'
  task restart: :environment do
    pumactl_command 'restart'
  end

  desc 'Restart puma (phased restart)'
  task phased_restart: :environment do
    pumactl_command 'phased-restart'
  end

  desc 'Restart puma (hard restart)'
  task hard_restart: :environment do
    invoke 'puma:stop'
    invoke 'puma:start'
  end

  desc 'Get status of puma'
  task status: :environment do
    pumactl_command 'status'
  end

  def pumactl_command(command)
    queue! %[
      if [ -e '#{pumactl_socket}' ]; then
        if [ -e '#{puma_config}' ]; then
          cd #{deploy_to}/#{current_path} && #{pumactl_cmd} -F #{puma_config} #{command}
        else
          cd #{deploy_to}/#{current_path} && #{pumactl_cmd} -S #{puma_state} -C 'unix://#{pumactl_socket}' --pidfile #{puma_pid} #{command}
        fi
      else
        echo 'Puma is not running!';
      fi
    ]
  end
end