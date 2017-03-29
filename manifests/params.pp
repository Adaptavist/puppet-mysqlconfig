class mysqlconfig::params {
    $mysql_root_password      = undef
    $bind_address             = '127.0.0.1'
    $custom_mysql_options     = {}
    $users                    = {}
    $grants                   = {}
    $max_allowed_packet       = '128M'
    $mysql_community_yum_name = 'mysql-community-release-el7-5'
    $mysql_community_yum_url  = 'https://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm'
    $mysql_community_server   = 'mysql-community-server'
    $mysql_community_client   = 'mysql-community-client'
    $create_admin_user_file   = true
    $admin_username           = 'administrator'
    $admin_password           = false
    $admin_file_location      = '/etc/mysql/debian.cnf'
    $init_script_timeout      = 0
    $init_overwrite_file      = '/etc/sysconfig/mysqld'
    $selinux_context = 'mysqld_db_t'
    $semanage_package = $::osfamily ? {
        'RedHat' => 'policycoreutils-python',
        'Debian' => 'policycoreutils',
    }
    $datadir = false
    $manage_config_file = true
    $install_community_repo = true
    case $::osfamily {
        'RedHat': {
            $server_service_name = 'mysqld'
            $log_error = '/var/log/mysqld.log'
            $pid_file = '/var/run/mysqld/mysqld.pid'
        }
        'Debian': {
            $server_service_name = 'mysql'
            $log_error = '/var/log/mysql/error.log'
            $pid_file = '/var/run/mysqld/mysqld.pid'
        }
        default: {
          fail("Unsupported osfamily: ${::osfamily}, currently only osfamily RedHat and Debian are suported")
        }
    }
}

