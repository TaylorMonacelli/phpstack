# Encoding: utf-8
#
# Cookbook Name:: phpstack
# Recipe:: php
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

if node['platform_version'].to_f <= 14.04
  default['php']['ext_conf_dir']  = '/etc/php5/cli/conf.d'
else
  default['php']['ext_conf_dir']  = '/etc/php5/conf.d'
end

default['phpstack']['pear']['modules'] = %w( mongo )

case node['platform_family']
when 'rhel'
  default['php']['packages'] = %w(
    php55u
    php55u-devel
    php55u-mcrypt
    php55u-mbstring
    php55u-gd
    php55u-pear
    php55u-pecl-memcache
    php55u-gmp
    php55u-mysqlnd
    php55u-xml )
  default['php']['ext_conf_dir']  = '/etc/php.d'
when 'debian'
  # the php5-common, php5-cgi, php5 ordering is needed to not install apache
  default['php']['packages'] = %w(
    php5-common
    php5-cgi
    php5
    php5-dev
    php5-mcrypt
    php5-gd
    php5-gmp
    php5-mysqlnd
    php-pear )
end
