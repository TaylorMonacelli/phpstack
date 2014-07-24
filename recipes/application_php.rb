# Encoding: utf-8
#
# Cookbook Name:: phpstack
# Recipe:: application_php
#
# Copyright 2014, Rackspace Hosting
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if platform_family?('rhel')
  include_recipe 'yum'
  include_recipe 'yum-epel'
  include_recipe 'yum-ius'
elsif platform_family?('debian')
  include_recipe 'apt'
end
include_recipe 'git'
include_recipe 'php'
include_recipe 'php::ini'
include_recipe 'php::module_mysql'
include_recipe 'phpstack::apache'
include_recipe 'php-fpm'
include_recipe 'chef-sugar'

# if gluster is in our environment, install the utils and mount it to /var/www
gluster_cluster = node['rackspace_gluster']['config']['server']['glusters'].values[0]
if gluster_cluster.key?('nodes')
  # get the list of gluster servers and pick one randomly to use as the one we connect to
  gluster_ips = []
  if gluster_cluster['nodes'].respond_to?('each')
    gluster_cluster['nodes'].each do |server|
      gluster_ips.push(server[1]['ip'])
    end
  end
  node.set_unless['phpstack']['gluster_connect_ip'] = gluster_ips.sample

  # install gluster mount
  package 'glusterfs-client' do
    action :install
  end

  # set up the mountpoint
  mount 'webapp-mountpoint' do
    fstype 'glusterfs'
    device "#{node['phpstack']['gluster_connect_ip']}:/#{node['rackspace_gluster']['config']['server']['glusters'].values[0]['volume']}"
    mount_point node['apache']['docroot_dir']
    action %w(mount enable)
  end
end

node['apache']['sites'].each do | site_name |
  site_name = site_name[0]

  application site_name do
    path node['apache']['sites'][site_name]['docroot']
    owner node['apache']['user']
    group node['apache']['group']
    deploy_key node['apache']['sites'][site_name]['deploy_key']
    repository node['apache']['sites'][site_name]['repository']
    revision node['apache']['sites'][site_name]['revision']
  end
end

if Chef::Config[:solo]
  Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
  mysql_node = nil
  rabbit_node = nil
else
  mysql_node = search('node', 'recipes:phpstack\:\:mysql_master' << " AND chef_environment:#{node.chef_environment}").first
  rabbit_node = search('node', 'recipes:phpstack\:\:rabbitmq' << " AND chef_environment:#{node.chef_environment}").first
end
puts 'simple deepfetch'
puts mysql_node.deep_fetch('apache', 'sites')
puts 'now with methods'
puts mysql_node.deep_fetch('apache', 'sites').methods.sort
template 'phpstack.ini' do
  path '/etc/phpstack.ini'
  cookbook node['phpstack']['ini']['cookbook']
  source 'phpstack.ini.erb'
  owner 'root'
  group node['apache']['group']
  mode '00640'
  variables(
    cookbook_name: cookbook_name,
    # if it responds then we will create the config section in the ini file
    mysql: if mysql_node.respond_to?('deep_fetch')
             mysql_node.deep_fetch('apache', 'sites').first['mysql_password'].nil? == false ? mysql_node : nil
           end,
    # need to do here because sugar is not available inside the template
    rabbit_host: if rabbit_node.respond_to?('deep_fetch')
                   best_ip_for(rabbit_node)
                 else
                   nil
                 end,
    rabbit_passwords: if rabbit_node.respond_to?('deep_fetch')
                        rabbit_node.deep_fetch('phpstack', 'rabbitmq', 'passwords').values[0].nil? == true ? nil : rabbit_node['phpstack']['rabbitmq']['passwords']
                      else
                        nil
                      end
  )
  action 'create'
end

# backups
node.default['rackspace']['datacenter'] = node['rackspace']['region']
node.set_unless['rackspace_cloudbackup']['backups_defaults']['cloud_notify_email'] = 'example@example.com'
# we will want to change this when https://github.com/rackspace-cookbooks/rackspace_cloudbackup/issues/17 is fixed
node.default['rackspace_cloudbackup']['backups'] =
  [
    {
      location: node['apache']['docroot_dir'],
      enable: node['phpstack']['rackspace_cloudbackup']['apache_docroot']['enable'],
      comment: 'Web Content Backup',
      cloud: { notify_email: node['rackspace_cloudbackup']['backups_defaults']['cloud_notify_email'] }
    }
  ]
