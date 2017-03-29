require 'spec_helper'
 options_redhat = {"mysqld"=>{
 	"max_allowed_packet"=>"128M",
 	"character-set-server"=>"utf8",
 	"collation_server"=>"utf8_bin",
 	"default-storage-engine"=>"innodb",
 	"transaction-isolation"=>"READ-COMMITTED",
  "bind_address"=>"127.0.0.1",
  "pid_file"=>"/var/run/mysqld/mysqld.pid",
  "log_error"=>"/var/log/mysqld.log"},
 	"client"=>{"default-character-set"=>"utf8"},
 	"mysql"=>{"max_allowed_packet"=>"128M"},
 	"mysqldump"=>{"max_allowed_packet"=>"128M"},
  "mysqld_safe"=>{"log_error"=>"/var/log/mysqld.log"}}


 options_debian = {"mysqld"=>{
  "max_allowed_packet"=>"128M",
  "character-set-server"=>"utf8",
  "collation_server"=>"utf8_bin",
  "default-storage-engine"=>"innodb",
  "transaction-isolation"=>"READ-COMMITTED",
  "bind_address"=>"127.0.0.1",
  "pid_file"=>"/var/run/mysqld/mysqld.pid",
  "log_error"=>"/var/log/mysql/error.log"},
  "client"=>{"default-character-set"=>"utf8"},
  "mysql"=>{"max_allowed_packet"=>"128M"},
  "mysqldump"=>{"max_allowed_packet"=>"128M"},
  "mysqld_safe"=>{"log_error"=>"/var/log/mysql/error.log"}}

root_password = "root_password"

community_package_name = "mysql-community-release-el7-5"
community_client_name = "mysql-community-client"
community_server_name = "mysql-community-server"

admin_file_location = "/etc/mysql/redhat.cnf"
admin_username = "redhat-sys-maint"
admin_password = "verysecure"

init_overwrite_file = '/tmp/mysqld'
init_add_timeout = "set STARTTIMEOUT 240"
init_remove_timeout = 'rm STARTTIMEOUT'

describe 'mysqlconfig', :type => 'class' do
    let(:params) { {:mysql_root_password => root_password} }
  context "On a Debian OS, force symlink creation with exec to avoid conflict with mysql module, password is not set" do
    let (:facts) {{ :osfamily => 'Debian'}}

    it {
      should contain_exec('symlink my.cnf').with({
        :command => "ln -sf /etc/mysql/debian.cnf /root/.my.cnf",
        :environment => 'HOME=/root'
      }).that_comes_before('Class[mysql::server]')
    }

    it {
      should contain_class('mysql::server').with(
    		'root_password' => "UNSET",
    		'override_options' => options_debian )
  	}
    it {
      should_not contain_package(community_package_name)
    }
  end

  context "Should run mysql server with parameters and set correct password in case of RedHat" do
    let (:facts) {
      { :osfamily => 'RedHat',
        :operatingsystemrelease => '6.5'
      }
    }

  	it {
  		should contain_class('mysql::server').with(
  			'override_options' => options_redhat,
  			'root_password' => root_password
  			)
  	}
    it {
      should_not contain_package(community_package_name)
    }
  end


  context "Should install the mysql community yum repo package on RedHat >= 7" do
    let (:facts) {
      { :osfamily => 'RedHat',
        :operatingsystemrelease => '7.1'
      }
    }
    let(:params) { 
      { :mysql_community_yum_name => community_package_name,
        :mysql_community_server => community_server_name,
        :mysql_community_client => community_client_name,
        :mysql_root_password => root_password

      } 
    }

    it {
      should contain_class('mysql::server').with(
        'override_options' => options_redhat,
        'root_password' => root_password,
        'package_name' => community_server_name
      )
    }
    it {
      should contain_class('mysql::client').with(
        'package_name' => community_client_name
      )
    }
    it {
      should contain_package(community_package_name)
    }
  end

context "Should create /etc/mysql/redhat.cnf on RedHat " do
    let (:facts) {
      { :osfamily => 'RedHat',
        :operatingsystemrelease => '6'
      }
    }
    let(:params) { 
      { :admin_file_location => admin_file_location,
        :admin_password => admin_password,
        :admin_username => admin_username
      } 
    }
    it {
      should contain_file(admin_file_location).with(
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'root',
          'mode'    => '0600'
      )
      credentials_file_test = catalogue().resource('file', admin_file_location).send(:parameters)[:content]
      File.read('spec/files/debian.cnf').should == credentials_file_test
    }

  end

context "Should not create /etc/mysql/redhat.cnf on RedHat if instructed not to" do
    let (:facts) {

      { :osfamily => 'RedHat',
        :operatingsystemrelease => '6'
      }
    }
    let(:params) { 
      { :admin_file_location => admin_file_location,
        :admin_password => admin_password,
        :admin_username => admin_username,
        :create_admin_user_file => "false"
      } 
    }
    it {
      should_not contain_file(admin_file_location)
    }
  end

context "Should not create /etc/mysql/redhat.cnf on Debian " do
    let (:facts) {
      { :osfamily => 'Debian' }
    }
    let(:params) { 
      { :admin_file_location => admin_file_location,
        :admin_password => admin_password,
        :admin_username => admin_username,
        :create_admin_user_file => "true"
      } 
    }
    it {
      should_not contain_file(admin_file_location)
    }
  end

  context "Should create start timeout override on RedHat <7" do
    let (:facts) {
      { :osfamily => 'RedHat',
        :operatingsystemrelease => '6.5'
      }
    }
    let(:params) { 
      { :init_script_timeout => 240,
        :init_overwrite_file => init_overwrite_file
      } 
    }

    it {
      should contain_augeas('mysql_init_timeout').with(
          'changes' => init_add_timeout,
          'lens'    => 'Shellvars.lns',
          'incl'    => init_overwrite_file,
      ).that_comes_before('Class[mysql::server]')
    }
  end

  context "Should remove start timeout override on RedHat <7" do
    let (:facts) {
      { :osfamily => 'RedHat',
        :operatingsystemrelease => '6.5'
      }
    }
    let(:params) { 
      { :init_script_timeout => 0,
        :init_overwrite_file => init_overwrite_file
      } 
    }

    it {
      should contain_augeas('mysql_init_timeout').with(
          'changes' => init_remove_timeout,
          'lens'    => 'Shellvars.lns',
          'incl'    => init_overwrite_file,
      ).that_comes_before('Class[mysql::server]')
    }
  end

  context "Should not have start timeout override on RedHat >= 7" do
    let (:facts) {
      { :osfamily => 'RedHat',
        :operatingsystemrelease => '7.0'
      }
    }
    let(:params) { 
      { :init_script_timeout => 240,
        :init_overwrite_file => init_overwrite_file
      } 
    }

    it {
      should_not contain_augeas('mysql_init_timeout')
    }
  end

  context "Should not have start timeout override on Debian" do
    let (:facts) {
      { :osfamily => 'Debian' }
    }
    let(:params) { 
      { :init_script_timeout => 240,
        :init_overwrite_file => init_overwrite_file
      } 
    }

    it {
      should_not contain_augeas('mysql_init_timeout')
    }
  end


end
