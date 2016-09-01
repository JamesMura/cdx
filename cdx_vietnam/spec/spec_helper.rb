ENV["RAILS_ENV"]   ||= 'test'
ENV["SINGLE_TENANT"] = 'false'

require File.expand_path("../dummy/config/environment.rb", __FILE__)
require 'rspec/rails'
require 'rspec/collection_matchers'
require 'paperclip/matchers'

require 'capybara/rspec'
require 'capybara/poltergeist'
require 'webmock/rspec'
require 'capybara-screenshot/rspec'

Capybara.javascript_driver = :poltergeist

Rails.backtrace_cleaner.remove_silencers!

# Load support files
require "#{CdxVietnam::Engine.root}/../cdx_core/features/support/page_objects/cdx_page_helper.rb"
require "#{CdxVietnam::Engine.root}/../cdx_core/features/support/page_objects/tests_run.rb"
require "#{CdxVietnam::Engine.root}/../cdx_core/features/support/page_objects/file_input.rb"
Dir["#{CdxVietnam::Engine.root}/../cdx_core/features/support/page_objects/*.rb"].each {|f| require f}
Dir["#{CdxVietnam::Engine.root}/../cdx_core/spec/support/**/*.rb"].each { |f| require f }

WebMock.disable_net_connect!(:allow_localhost => true, allow: [/fonts\.googleapis\.com/, /manastech\.testrail\.com/])

# This is to make machinist work with Rails 4
class ActiveRecord::Reflection::AssociationReflection
  def primary_key_name
    foreign_key
  end
end


RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.render_views
  config.infer_spec_type_from_file_location!

  config.mock_with :rspec do |mocks|
    # This option should be set when all dependencies are being loaded
    # before a spec run, as is the case in a typical spec helper. It will
    # cause any verifying double instantiation for a class that does not
    # exist to raise, protecting against incorrectly spelt names.
    mocks.verify_doubled_constant_names = true
  end

  config.use_transactional_fixtures = false
  config.infer_base_class_for_anonymous_controllers = false
  config.order = "random"

  config.example_status_persistence_file_path = 'examples.txt'

  config.include Devise::TestHelpers, :type => :controller
  config.include DefaultParamsHelper, :type => :controller
  config.include ManifestSpecHelper
  config.include CdxFieldsHelper
  config.include FeatureSpecHelpers, :type => :feature
  config.include Paperclip::Shoulda::Matchers

  config.before(:each) do
    stub_request(:get, "http://fonts.googleapis.com/css").
         with(:query => hash_including(:family)).
         to_return(:status => 200, :body => "", :headers => {})
  end

  config.before(:each) do
    LocationService.fake!
    Timecop.return
    ActionMailer::Base.deliveries.clear
  end

  config.after(:each) do
    Timecop.return
  end
end

require "bundler/setup"
require "cdx"
require "pry-byebug"
