#####
##### Tomcat Webapp Custom Resource for Webops
##### Author: Nate Stewart
##### Date: 02/07/2017

property :instance_name, String, name_property: true
property :install_path, String, default: '/opt/web_apps/'

property :tomcat_user, String, default: 'tomcat'
property :tomcat_group, String, default: 'tomcat'

# where to symlink the tomcat directory inside the app
property :tomcat_path, String, default: '/opt/tomcat'

# remove .disabled file in the app so that the tomcat script can start it
property :remove_disable_file, [true, false], default: false

# catalina.sh and setenv.sh parameters
property :java_home, String, default: '/opt/jre'
property :jmx_opts, String, default: ''
property :app_specific_opts, String, default: ''
property :db_properties, String, default: ''

# for custom context.xml as some apps require it, disables auto symlink to tomcat context.xml
property :custom_context, [true, false], default: false

# templating parameters
property :template_cookbook, String, default: 'xact_app_java'
property :port_shutdown, Integer, required: true
property :port_httpconnector, Integer, required: true
property :port_ajpconnector, Integer, required: true
property :port_ssl, Integer, required: true
property :max_threads, Integer, required: true
property :servername, String, default: node['hostname']
property :server_xml_template, String, required: true
property :setenv_sh_template, String, default: 'setenv.sh.erb'
property :catalina_sh_template, String, default: 'catalina.sh.erb'

action_class do
  # Make sure the install path starts and ends with / to not break the directory creation
  def validate_installpath
    unless new_resource.install_path =~ %r{/.*/$}
      Chef::Log.fatal("The install path must start and end with a /    Passed value: #{new_resource.install_path}")
      fail
    end
  end

  def create_tomcat_user
    group new_resource.tomcat_group do
      action :create
      append true
    end
    user new_resource.tomcat_user do
      gid new_resource.tomcat_group
      shell '/bin/false'
      system true
      action :create
    end
  end

  def build_root_directory
    directory "#{new_resource.install_path}#{new_resource.instance_name}" do
      owner new_resource.tomcat_user
      group new_resource.tomcat_group
      mode '755'
      recursive true
    end
  end

  def build_directory_structure
    tomcat_folders = %w(docroot temp archive bin webapps logs lib conf work)
    tomcat_folders.each do |t1|
      directory "#{new_resource.install_path}#{new_resource.instance_name}/#{t1}" do
        owner new_resource.tomcat_user
        group new_resource.tomcat_group
        mode '755'
      end
    end
    conf_folders = %w(conf/db conf/app)
    conf_folders.each do |t1|
      directory "#{new_resource.install_path}#{new_resource.instance_name}/#{t1}" do
        owner new_resource.tomcat_user
        group new_resource.tomcat_group
        mode '700'
      end
    end
  end

  def create_symlinks
    link "#{new_resource.install_path}#{new_resource.instance_name}/tomcat" do
      to new_resource.tomcat_path
      not_if { ::File.directory?("#{new_resource.install_path}#{new_resource.instance_name}/tomcat") }
    end

    link "#{new_resource.install_path}#{new_resource.instance_name}/conf/catalina.policy" do
      to "#{new_resource.install_path}#{new_resource.instance_name}/tomcat/conf/catalina.policy"
    end

    link "#{new_resource.install_path}#{new_resource.instance_name}/conf/catalina.properties" do
      to "#{new_resource.install_path}#{new_resource.instance_name}/tomcat/conf/catalina.properties"
    end

    link "#{new_resource.install_path}#{new_resource.instance_name}/conf/context.xml" do
      to "#{new_resource.install_path}#{new_resource.instance_name}/tomcat/conf/context.xml"
      not_if { new_resource.custom_context }
    end

    link "#{new_resource.install_path}#{new_resource.instance_name}/conf/logging.properties" do
      to "#{new_resource.install_path}#{new_resource.instance_name}/tomcat/conf/logging.properties"
    end

    link "#{new_resource.install_path}#{new_resource.instance_name}/conf/web.xml" do
      to "#{new_resource.install_path}#{new_resource.instance_name}/tomcat/conf/web.xml"
    end

    link "#{new_resource.install_path}#{new_resource.instance_name}/webapps/manager" do
      to "#{new_resource.install_path}#{new_resource.instance_name}/tomcat/webapps/manager"
      not_if { ::File.directory?("#{new_resource.install_path}#{new_resource.instance_name}/webapps/manager") }
    end
  end

  def create_launch_scripts
    template "#{new_resource.install_path}#{new_resource.instance_name}/bin/catalina.sh" do
      source new_resource.catalina_sh_template
      cookbook new_resource.template_cookbook
      owner new_resource.tomcat_user
      group new_resource.tomcat_group
      variables :java_home => new_resource.java_home
      mode '0700'
      action :create
    end

    template "#{new_resource.install_path}#{new_resource.instance_name}/bin/setenv.sh" do
      source new_resource.setenv_sh_template
      cookbook new_resource.template_cookbook
      owner new_resource.tomcat_user
      group new_resource.tomcat_group
      variables(:jmx_opts => new_resource.jmx_opts,
                :app_specific_opts => new_resource.app_specific_opts,
                :db_properties => new_resource.db_properties)
      mode '0600'
      action :create
    end
  end

  def create_app_config
    template "#{new_resource.install_path}#{new_resource.instance_name}/conf/server.xml" do
      source new_resource.server_xml_template
      cookbook new_resource.template_cookbook
      owner new_resource.tomcat_user
      group new_resource.tomcat_group
      variables(:port_shutdown => new_resource.port_shutdown,
                :port_ajpconnector => new_resource.port_ajpconnector,
                :port_httpconnector => new_resource.port_httpconnector,
                :max_threads => new_resource.max_threads,
                :port_ssl => new_resource.port_ssl,
                :servername => new_resource.servername)
      mode '0600'
      action :create
    end

    cookbook_file "#{new_resource.install_path}#{new_resource.instance_name}/conf/tomcat-users.xml" do
      source 'tomcat-users.xml'
      cookbook 'xact_app_java'
      owner new_resource.tomcat_user
      group new_resource.tomcat_group
      mode '0600'
      action :create
    end

    cookbook_file "#{new_resource.install_path}#{new_resource.instance_name}/conf/jmxremote.access" do
      source 'jmxremote.access'
      cookbook 'xact_app_java'
      owner new_resource.tomcat_user
      group new_resource.tomcat_group
      mode '0600'
      action :create
    end

    cookbook_file "#{new_resource.install_path}#{new_resource.instance_name}/conf/jmxremote.password" do
      source 'jmxremote.password'
      cookbook 'xact_app_java'
      owner new_resource.tomcat_user
      group new_resource.tomcat_group
      mode '0600'
      action :create
    end
  end

  def enable_app
    file "#{new_resource.install_path}#{new_resource.instance_name}/.disabled" do
      content ''
      owner 'root'
      group 'root'
      mode '0644'
      action :delete
      only_if { new_resource.remove_disable_file }
    end
  end
end

default_action :install

action :install do
  validate_installpath

  create_tomcat_user

  build_root_directory

  build_directory_structure

  create_symlinks

  create_launch_scripts

  create_app_config

  enable_app
end

action :disable do
  file "#{new_resource.install_path}#{new_resource.instance_name}/.disabled" do
    content ''
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end
end
