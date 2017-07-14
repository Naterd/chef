#####
##### JAVA Custom Resource for Webops. Written by Nate.S
#####

property :instance_name, String, name_property: true
## Version needs to be NUMBER+u+NUMBER IE 7u40 or 8u11 to match the filenames in our repo
property :version, String, name_property: true
property :install_path, String, required: true
property :tarball_base_path, String, default: 'http://itopalias/apps/linux/java/'
## Give this property if you want to directly specify where to pull the java tar ball from
property :tarball_uri, String
property :java_user, String, default: 'root'
property :java_group, String, default: 'root'
property :master_jre, [true, false], default: false

action_class do
  # ensure the version is XuYZ or XuY format
  def validate_version
    unless new_resource.version =~ /\d{1}u\d{1,3}/
      Chef::Log.fatal("The version must be in XuYZ or XuY format IE 7u45 or 8u11 or 7u7. Passed value: #{new_resource.version}")
      fail
    end
  end

  def tarball_uri
    uri = ''
    if new_resource.tarball_uri.nil?
      uri << new_resource.tarball_base_path
      uri << '/' unless uri[-1] == '/'
      uri << "server-jre-#{new_resource.version}-linux-x64.tar.gz"
    else
      uri << new_resource.tarball_uri
    end
    uri
  end

  def create_symlink
    jrepath = "#{new_resource.install_path}"
    jrepath << '/' unless jrepath[-1] == '/'
    jrepath << 'jre'

    link '/opt/jre7' do
      to jrepath
      only_if { new_resource.version =~ /\A7u\d{1,}/ }
    end

    link '/opt/jre8' do
      to jrepath
      only_if { new_resource.version =~ /\A8u\d{1,}/ }
    end

    return unless new_resource.master_jre
    serverjrepath = "#{new_resource.install_path}"
    serverjrepath << '/' unless serverjrepath[-1] == '/'

    link '/opt/server-jre' do
      to serverjrepath
    end

    link '/opt/jre' do
      to '/opt/server-jre/jre'
    end
  end
end

default_action :install

action :install do
  validate_version

  # some RHEL systems lack tar in their minimal install
  package 'tar'

  group new_resource.java_group do
    action :create
    append true
  end

  user new_resource.java_user do
    gid new_resource.java_group
    system true
    action :create
  end

  directory 'java install dir' do
    mode '0755'
    path new_resource.install_path
    recursive true
    owner new_resource.java_user
    group new_resource.java_group
  end

  remote_file "java #{new_resource.version} tarball" do
    source tarball_uri
    path "#{Chef::Config['file_cache_path']}/server-jre-#{new_resource.version}-linux-x64.tar.gz"
  end

  execute 'extract java tarball' do
    command "tar -xzf #{Chef::Config['file_cache_path']}/server-jre-#{new_resource.version}-linux-x64.tar.gz -C #{new_resource.install_path} --strip-components=1"
    action :run
    creates ::File.join(new_resource.install_path, 'LICENSE')
  end

  # make sure the instance's user owns the instance install dir
  execute 'chown install dir as java_user resource property' do
    command "chown -R #{new_resource.java_user}:#{new_resource.java_group} #{new_resource.install_path}"
    action :run
    not_if { Etc.getpwuid(::File.stat("#{new_resource.install_path}/LICENSE").uid).name == new_resource.java_user }
  end

  create_symlink
end
