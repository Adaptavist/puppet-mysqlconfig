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
    $init_script_timeout      = 0,
    $init_overwrite_file      = '/etc/sysconfig/mysqld'
}