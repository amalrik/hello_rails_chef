version = "0.13"
remote_file "/tmp/remote_syslog.tar.gz" do 
  source "https://github.com/papertrail/remote_syslog2/releases/download/v#{version}/remote_syslog_linux_amd64.tar.gz"
  not_if do
    File.exists?("/usr/local/bin/remote_syslog")
  end
  notifies :run, "execute[untar remote_syslog]"
end

execute "untar remote_syslog" do
  cwd '/tmp'
  command 'tar xzf remote_syslog.tar.gz'
  action :nothing
  notifies :run, "execute[copy remote_syslog]"
end

execute "copy remote_syslog" do
  command "cp /tmp/remote_syslog/remote_syslog /usr/local/bin && rm -rf /tmp/remote_syslo*"
  action :nothing
  notifies :start, "service[remote_syslog]"
end

template "/etc/init/remote_syslog.conf" do
  source "remote_syslog.upstart.conf.erb"
end

template "/etc/log_files.yml" do
  source "log_files.yml.erb"
end

service "remote_syslog" do
  provider Chef::Provider::Service::Upstart
  action :nothing
  supports start: true
end