include_recipe "deploy"
include_recipe "nginx::service"

node[:deploy].each do |application, deploy|
  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  ['tmp'].each do |dir_name|
    directory "#{params[:path]}/shared/#{dir_name}" do
      group deploy[:group]
      owner deploy[:user]
      mode 0770
      action :create
      recursive true
    end
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  current_instance = node["opsworks"]["instance"]["hostname"]

  link "#{deploy[:deploy_to]}/current/tmp/sockets" do
    to "#{deploy[:deploy_to]}/shared/sockets"
    owner deploy[:user]
    group deploy[:group]
  end

  execute "bundle install --binstubs #{deploy[:deploy_to]}/shared/bin --path #{deploy[:deploy_to]}/shared/bundle --deployment --without development test" do
    user deploy[:user]
    group deploy[:group]
    cwd "#{deploy[:deploy_to]}/current"
  end

  template "#{deploy[:deploy_to]}/current/config/database.yml" do
    source "database.yml.erb"
    user deploy[:user]
    group deploy[:group]
    variables({
      rails_env: deploy[:rails_env],
      database: deploy[:environment_variables]
    })
  end

  template "#{deploy[:deploy_to]}/current/public/robots.txt" do
    source "robots.txt.erb"
    user deploy[:user]
    group deploy[:group]
    variables rails_env: deploy[:rails_env]
  end

  execute "bundle exec rake assets:precompile" do
    user deploy[:user]
    group deploy[:group]
    cwd "#{deploy[:deploy_to]}/current"
    environment({
      "RAILS_ENV" => deploy[:rails_env],
      "RAILS_GROUPS" => "assets",
    }.merge(deploy[:environment_variables]))
  end

  if node["opsworks"]["instance"]["layers"].include?("application")
    instances = node["opsworks"]["layers"]["application"]["instances"].keys

    if instances.first == current_instance
      execute "bundle exec rake db:migrate" do
        user deploy[:user]
        group deploy[:group]
        cwd "#{deploy[:deploy_to]}/current"
        environment({
          "RAILS_ENV" => deploy[:rails_env]
        }.merge(deploy[:environment_variables]))
      end
    end
  end

  template "#{deploy[:deploy_to]}/current/.env" do
    source "dotenv.erb"
    user deploy[:user]
    group deploy[:group]
    variables dotenv: deploy[:environment_variables]
  end

  execute "bundle exec foreman export upstart /etc/init -a #{application} -u #{deploy[:user]} -l /var/log/#{application}" do
    cwd "#{deploy[:deploy_to]}/current"
  end

  execute "service #{application} restart || service #{application} start"
end
