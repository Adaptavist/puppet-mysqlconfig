require 'rubygems'
require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end