# Copyright 2011 MaestroDev
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

# This activemq class is currently targeting an X86_64 deploy, adjust as needed

class activemq($jdk_package = "java-1.6.0-openjdk", 
               $apache_mirror = "http://archive.apache.org/dist/", 
               $version = "5.5.0", 
               $home = "/opt", 
               $user = "activemq",
               $group = "activemq",
               $system_user = true,
               $max_memory = "512") {

  # wget from https://github.com/maestrodev/puppet-wget
  include wget

  if ! defined (Package[$jdk_package]) {
    package { $jdk_package: ensure => installed }
  }

  user { $user:
    ensure     => present,
    home       => "$home/$user",
    managehome => false,
    shell      => "/bin/false",
    system     => $system_user,
  }

  group { $group:
    ensure  => present,
    system  => $system_user,
    require => User[$user],
  }

  wget::fetch { "activemq_download":
    source => "$apache_mirror/activemq/apache-activemq/$version/apache-activemq-${version}-bin.tar.gz",
    destination => "/usr/local/src/apache-activemq-${version}-bin.tar.gz",
    require => [User[$user],Group[$group],Package[$jdk_package]],
  } ->
  exec { "activemq_untar":
    command => "tar xf /usr/local/src/apache-activemq-${version}-bin.tar.gz && chown -R $user:$group $home/apache-activemq-$version",
    cwd     => "$home",
    creates => "$home/apache-activemq-$version",
    path    => ["/bin",],
  } ->
  file { "$home/activemq":
    ensure  => "$home/apache-activemq-$version",
    require => Exec["activemq_untar"],
  } ->
  file { "/etc/activemq":
    ensure  => "$home/activemq/conf",
    require => File["$home/activemq"],
  } ->
  file { "/var/log/activemq":
    ensure  => "$home/activemq/data",
    require => File["$home/activemq"],
  } ->
  file { "$home/activemq/bin/linux":
    ensure  => "$home/activemq/bin/linux-x86-64",
    require => File["$home/activemq"],
  } ->
  file { "/var/run/activemq":
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => 755,
    require => [User[$user],Group[$group]],
  } ->
  file { "/etc/init.d/activemq":
    owner   => root,
    group   => root,
    mode    => 755,
    content => template("activemq/activemq-init.d.erb"),
  }

  case $architecture {
    'x86_64': {
      file { "wrapper.conf":
        path    => "$home/apache-activemq-$version/bin/linux-x86-64/wrapper.conf",
        owner   => $user,
        group   => $group,
        mode    => 644,
        content => template("activemq/wrapper.conf.erb"),
        require => [File["$home/activemq"],File["/etc/init.d/activemq"]]
      }  
    }
    'i386': {
      file { "wrapper.conf":
        path    => "$home/apache-activemq-$version/bin/linux-x86-32/wrapper.conf",
        owner   => $user,
        group   => $group,
        mode    => 644,
        content => template("activemq/wrapper.conf.erb"),
        require => [File["$home/activemq"],File["/etc/init.d/activemq"]]
      }
    }
  }

  file { "/etc/activemq/activemq.xml":
    owner   => $user,
    group   => $group,
    mode    => 644,
    source  => "puppet://${servername}/modules/activemq/activemq.xml",
    require => [File["wrapper.conf"],File["/etc/activemq"]],
    notify => Service["activemq"]
  }

  service { "activemq":
    name => "activemq",
    ensure => running,
    hasrestart => true,
    hasstatus => false,
    enable => true,
    require => [User["$user"],Group["$group"],Package[$jdk_package]],
    subscribe => File["/etc/activemq/activemq.xml"]
  }
  
}
