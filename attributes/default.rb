#
# Cookbook Name:: cheftest
# Attributes:: default
#
# Author:: Alex Manly (<alex.manly@sendachi.com>)
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

# default attributes change depending on platform
default['cheftest']['web_root'] = '/var/www/html'
case node['platform_family']
when 'debian'
  default['cheftest']['package_name'] = 'apache2'
  default['cheftest']['service_name'] = 'apache2'
else
  default['cheftest']['package_name'] = 'httpd'
  default['cheftest']['service_name'] = 'httpd'
end

default['cheftest']['feature_flag'] = false
