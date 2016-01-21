include_recipe "nginx::service"

package "imagemagick"

node[:deploy].each do |application, deploy|
  template "/etc/nginx/sites-available/#{application}" do
    source "nginx.conf.erb"
    owner "root"
    group "root"
    mode 00644
    variables({
      "application" => application,
      "deploy" => deploy
    })
  end

  nginx_site application, enabled: true
end
