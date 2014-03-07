# == Class: zookeeper
#
#
class zookeeper(
  $id,
  $servername          = $fqdn,
  $servers             = ['server1','server2','server3'],
  $mirror_location     = 'http://ftp.nluug.nl/internet/apache/zookeeper/',
  $version             = '3.4.5',
  $user                = 'hduser',
  $group               = 'hadoop',
  $base_path           = '/opt/zookeeper',
  $conf_path           = '/opt/zookeeper/zookeeper/conf',
  $user_path           = '/home/hduser',
  $data_path           = '/var/zookeeper',
){

  include java
  $java_home = $java::params::java['jdk']['java_home']

  group { $group:
    ensure             => present,
    gid                => "800"
  }

  user { $user:
    ensure             => present,
    comment            => "Zookeeper",
    password           => "!!",
    uid                => "800",
    gid                => "800",
    shell              => "/bin/bash",
    home               => $user_path,
    require            => Group[$group],
  }

  file { "${user_path}/.bashrc":
    ensure             => present,
    owner              => $user,
    group              => $group,
    alias              => "${user}-bashrc",
    content            => template("zookeeper/home/bashrc.erb"),
    require            => [ User[$user], File["${user}-home"] ]
  }


  file { $user_path:
    ensure             => "directory",
    owner              => $user,
    group              => $group,
    alias              => "${user}-home",
    require            => [ User[$user], Group[$group] ]
  }
 
  file { $data_path:
    ensure             => "directory",
    owner              => $user,
    group              => $group,
    alias              => "zookeeper-data-dir",
    require            => File["${user}-home"]
  }
 
  file { $base_path:
    ensure             => "directory",
    owner              => $user,
    group              => $group,
    alias              => "zookeeper-base",
  }

  file { $conf_path:
    ensure             => "directory",
    owner              => $user,
    group              => $group,
    alias              => "zookeeper-conf",
    require            => [File[$base_path], Exec["untar-zookeeper"]],
    before             => [ File["zoo-cfg"] ]
  }
 
  exec { 'zookeeper download':
    command            => "/usr/bin/wget -q -O ${base_path}/zookeeper-${version}.tar.gz ${mirror_location}/zookeeper-${version}/zookeeper-${version}.tar.gz",
    unless             => "/usr/bin/test -f ${base_path}/zookeeper-${version}.tar.gz",
    require            => File[$base_path],
  }

  file { "${base_path}/zookeeper-${version}.tar.gz":
    mode               => 0644,
    owner              => $user,
    group              => $group,
    alias              => "zookeeper-source-tgz",
    before             => Exec["untar-zookeeper"],
    require            => Exec['zookeeper download']
  }

  exec { "untar zookeeper-${version}.tar.gz":
    command            => "tar xfvz zookeeper-${version}.tar.gz",
    cwd                => "${base_path}",
    creates            => "${base_path}/zookeeper-${version}",
    alias              => "untar-zookeeper",
    refreshonly        => true,
    subscribe          => File["zookeeper-source-tgz"],
    user               => $user,
    before             => [ File["zookeeper-symlink"], File["zookeeper-app-dir"]],
    path               => ["/bin", "/usr/bin", "/usr/sbin"],
  }

  file { "${base_path}/zookeeper-${version}":
    ensure             => "directory",
    mode               => 0644,
    owner              => $user,
    group              => $group,
    alias              => "zookeeper-app-dir",
    require            => Exec["untar-zookeeper"],
  }

  file { "${base_path}/zookeeper":
    force              => true,
    ensure             => "${base_path}/zookeeper-${version}",
    alias              => "zookeeper-symlink",
    owner              => $user,
    group              => $group,
    require            => File["zookeeper-source-tgz"],
    before             => [ File["zoo-cfg"] ]
  }

  file { "${base_path}/zookeeper-${version}/conf/zoo.cfg":
    owner              => $user,
    group              => $group,
    mode               => "644",
    alias              => "zoo-cfg",
    require            => File["zookeeper-app-dir"],
    content            => template("zookeeper/conf/zoo.cfg"),
  }

  file { "${data_path}/myid":
    owner              => $user,
    group              => $group,
    mode               => "644",
    content            => $id,
    require            => File["zookeeper-data-dir"],
    alias              => "zookeeper-myid",
  }

  exec { "Launch zookeeper":
    command            => "./zkServer.sh start",
    user               => $user,
    cwd                => "${base_path}/zookeeper-${version}/bin",
    path               => ["/bin", "/usr/bin", "${base_path}/zookeeper-${version}/bin", "${java_home}"],
    require            => [File["${base_path}/zookeeper-${version}/conf/zoo.cfg"],File["${data_path}/myid"]],
    unless             => "ps -aux | grep 'zookeeper.server' | grep -v grep"
  }

}
