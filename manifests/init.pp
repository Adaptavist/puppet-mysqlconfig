class mysqlconfig (
        $mysql_root_password      = $mysqlconfig::params::mysql_root_password,
        $bind_address             = $mysqlconfig::params::bind_address,
        $custom_mysql_options     = $mysqlconfig::params::custom_mysql_options,
        $users                    = $mysqlconfig::params::users,
        $grants                   = $mysqlconfig::params::grants,
        $max_allowed_packet       = $mysqlconfig::params::max_allowed_packet,
        $mysql_community_yum_name = $mysqlconfig::params::mysql_community_yum_name,
        $mysql_community_yum_url  = $mysqlconfig::params::mysql_community_yum_url,
        $mysql_community_server   = $mysqlconfig::params::mysql_community_server,
        $mysql_community_client   = $mysqlconfig::params::mysql_community_client,
        # purpose of this is to replicate debian system maintenence account
        $create_admin_user_file   = $mysqlconfig::params::create_admin_user_file,
        $admin_username           = $mysqlconfig::params::admin_username,
        $admin_password           = $mysqlconfig::params::admin_password,
        $admin_file_location      = $mysqlconfig::params::admin_file_location,
        $init_script_timeout      = $mysqlconfig::params::init_script_timeout,
        $init_overwrite_file      = $mysqlconfig::params::init_overwrite_file,
        $selinux_context          = $mysqlconfig::params::selinux_context,
        $semanage_package         = $mysqlconfig::params::semanage_package,
        $datadir                  = $mysqlconfig::params::datadir,
    ) inherits mysqlconfig::params {
    # override environment vars in mysql module exec resources
    # this allows us to use old password cached in /root/.my.cnf
    # which means we dont have to ask the administrator to also
    # configure an 'old' password aswell (*yuck*)
    Exec {
        environment => 'HOME=/root'
    }

    if $::osfamily == 'Debian' {
        # force symlink creation with exec
        # to avoid conflict with mysql module
        exec { 'symlink my.cnf':
            command => 'ln -sf /etc/mysql/debian.cnf /root/.my.cnf',
            before  => Class['mysql::server'],
        }
    }

    $root_password = $::osfamily ? {
        'RedHat' => $mysql_root_password,
        default  => undef,
    }

    if $::host != undef {
        validate_hash($::host)
        if $host['mysqlconfig::bind_address'] == undef {
            $custom_bind_address = $bind_address
        } else {
            $custom_bind_address = $host['mysqlconfig::bind_address']
        }

        if $host['mysqlconfig::custom_mysql_options'] == undef {
            $host_override_options = {}
        }
        else {
            $host_override_options = $host['mysqlconfig::custom_mysql_options']
        }

        if $host['mysqlconfig::grants'] == undef {
            $host_grants = {}
        }
        else {
            $host_grants = $host['mysqlconfig::grants']
        }

        if $host['mysqlconfig::users'] == undef {
            $host_users = {}
        }
        else {
            $host_users = $host['mysqlconfig::users']
        }
    } else {
        $custom_bind_address = $bind_address
        $host_override_options = {}
        $host_users = {}
        $host_grants = {}
    }
    $default_override_options = {
        'mysqld' => {
            'max_allowed_packet'     => $max_allowed_packet,
            'character-set-server'   => 'utf8',
            'collation_server'       => 'utf8_bin',
            'default-storage-engine' => 'innodb',
            'transaction-isolation'  => 'READ-COMMITTED',
            'bind_address'           => $custom_bind_address,
        },
        'client' => {
            'default-character-set'  => 'utf8'
        },
        'mysql' => {
            'max_allowed_packet'     => $max_allowed_packet
        },
        'mysqldump' => {
            'max_allowed_packet'     => $max_allowed_packet
        }
    }
    if ($::osfamily == 'RedHat') {
        # override init script timeout if a valid timeout (not 0) is set (currently only set for RH/CentOS <= 6)
        if (versioncmp($::operatingsystemrelease,'7') == -1 and $::operatingsystem != 'Fedora' and is_numeric($init_script_timeout)) {
            if ($init_script_timeout == 0) {
                $init_overwrite_action = 'rm STARTTIMEOUT'
            } else {
                $init_overwrite_action = "set STARTTIMEOUT ${init_script_timeout}"
            }
            augeas { 'mysql_init_timeout':
                lens    => 'Shellvars.lns',
                incl    => $init_overwrite_file,
                changes => $init_overwrite_action,
                before  => Class['mysql::server'],
            }
        }
        # create an admin acccount (equivalent to debian-sys-maint) if required
        if (str2bool($create_admin_user_file)){
            if ($admin_password != false and $admin_password != 'false') {
                $real_admin_password = $admin_password
            } else {
                $real_admin_password = fqdn_rand_string(10)
            }
            file {
                $admin_file_location:
                    ensure  => file,
                    content => template("${module_name}/admin_file.cfg.erb"),
                    owner   => 'root',
                    group   => 'root',
                    mode    => '0600',
                    require => Class['mysql::server']
            }

            $admin_user_hash = {
                "${admin_username}@localhost" => {
                    'ensure' => 'present',
                    'password_hash' => mysql_password($real_admin_password),
                }
            }
            $mysql_users = merge($users, $host_users, $admin_user_hash)

            $admin_user_grant_hash = {
                "${admin_username}" => {
                    'table' => '*.*',
                    'user' => "${admin_username}@localhost",
                    'options' => ['GRANT'],
                    'privileges' => ['ALL'],
                }
            }
            $mysql_grants = merge($grants, $host_grants, $admin_user_grant_hash)
        } else {
            $mysql_users = merge($users, $host_users)
            $mysql_grants = merge($grants, $host_grants)
        }
    } else {
        $mysql_users = merge($users, $host_users)
        $mysql_grants = merge($grants, $host_grants)
    }

    $override_options = merge($default_override_options, $custom_mysql_options, $host_override_options)
    
    # if selinux is enabled and we have a custom datadir set the correct selinux context
    if (str2bool($::selinux) and $datadir != 'false' and $datadir != false) {
        ensure_packages([$semanage_package])

        exec { 'mysql_datadir_selinux':
            command => "semanage fcontext -a -t ${selinux_context} \"${datadir}(/.*)?\" && restorecon -R -v ${datadir}",
            before  => Class['mysql::server']
        }
    }

    # if this is CentOS/RHEL >= 7 install the mysql community YUM repo and install the community MySQL server/client as CentOS/RHEL >= 7 ship with MariaDB
    if ($::osfamily == 'RedHat') and (versioncmp($::operatingsystemrelease,'7') >= 0 and $::operatingsystem != 'Fedora') {
        # install the RPM package containing the MySQL community yum repo
        package { $mysql_community_yum_name:
            ensure   => 'installed',
            source   => $mysql_community_yum_url,
            provider => 'rpm',
            before   => [Class['mysql::server'], Class['mysql::client']]
        }
        class { 'mysql::server' :
            root_password    => $root_password,
            override_options => $override_options,
            users            => $mysql_users,
            grants           => $mysql_grants,
            package_name     => $mysql_community_server
        }
        class { 'mysql::client' :
            package_name     => $mysql_community_client
        }
    } else {
        class { 'mysql::server' :
            root_password    => $root_password,
            override_options => $override_options,
            users            => $mysql_users,
            grants           => $mysql_grants
        }
    }
}
