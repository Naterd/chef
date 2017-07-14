#####
##### Nginx Custom Resource for Webops
#####

property :site_name, String, name_property: true
property :nginx_path, String, default: '/etc/nginx'
property :auto_enable, [true, false], default: true
property :conf_source, String, required: true

property :webroot, [Array, String]
property :nginx_user, String, default: 'root'
property :nginx_group, String, default: 'root'
property :nginx_binary, String, default: '/usr/sbin/nginx'

default_action :create

action :create do

  cookbook_file "#{new_resource.nginx_path}/sites-available/#{new_resource.site_name}.conf" do
    owner new_resource.nginx_user
    group new_resource.nginx_group
    mode '644'
    source new_resource.conf_source
  end

  link "#{new_resource.nginx_path}/sites-enabled/#{new_resource.site_name}.conf" do
    to "#{new_resource.nginx_path}/sites-available/#{new_resource.site_name}.conf"
    only_if { new_resource.auto_enable }
    notifies :restart, 'service[nginx]', :delayed
  end

  if !new_resource.webroot.nil? && new_resource.webroot.respond_to?(:each)
    new_resource.webroot.each do |dir|
      directory dir do
        owner new_resource.nginx_user
        group new_resource.nginx_group
        mode '0755'
        recursive true
        action :create
      end
    end
  else
    directory new_resource.webroot do
      owner new_resource.nginx_user
      group new_resource.nginx_group
      mode '0755'
      recursive true
      action :create
      not_if { new_resource.webroot.empty? }
    end
  end
end

action :delete do
  link "#{new_resource.nginx_path}/sites-enabled/#{new_resource.site_name}.conf" do
    to "#{new_resource.nginx_path}/sites-available/#{new_resource.site_name}.conf"
    action :delete
  end

  file "#{new_resource.nginx_path}/sites-available/#{new_resource.site_name}.conf" do
    action :delete
    notifies :restart, 'service[nginx]', :delayed
  end
end

action :enable do
  link "#{new_resource.nginx_path}/sites-enabled/#{new_resource.site_name}.conf" do
    to "#{new_resource.nginx_path}/sites-available/#{new_resource.site_name}.conf"
    notifies :restart, 'service[nginx]', :delayed
  end
end

action :disable do
  link "#{new_resource.nginx_path}/sites-enabled/#{new_resource.site_name}.conf" do
    to "#{new_resource.nginx_path}/sites-available/#{new_resource.site_name}.conf"
    action :delete
    notifies :restart, 'service[nginx]', :delayed
  end
end
