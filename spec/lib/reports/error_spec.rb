require 'spec_helper'

RSpec.describe Reports::Errors, elasticsearch: true do
  let(:current_user) { User.make }
  let(:site_user) { "#{current_user.first_name} #{current_user.last_name}" }
  let(:institution) { Institution.make(user_id: current_user.id) }
  let(:site) { Site.make(institution: institution) }
  let(:current_user_two) { User.make }
  let(:institution_two) { Institution.make(user_id: current_user_two.id) }
  let(:site_two) { Site.make(institution: institution_two) }
  let(:user_device) { Device.make institution_id: institution.id, site: site }
  let(:user_device_two) { Device.make institution_id: institution_two.id, site: site_two }
  
  let(:nav_context) { NavigationContext.new(current_user, institution.uuid) }

  before do
    TestResult.create_and_index(
      core_fields: {
        'assays' => ['condition' => 'mtb', 'result' => :positive],
        'start_time' => Time.now,
        'name' => 'mtb',
        'status' => 'error',
        'site_user' => site_user
      },
      device_messages:[DeviceMessage.make(device: user_device)]
    )

    TestResult.create_and_index(
      core_fields: {
        'assays' => ['condition' => 'mtb', 'result' => :negative],
        'start_time' => Time.now - 1.month,
        'name' => 'mtb',
        'status' => 'error',
        'site_user' => site_user
      },
      device_messages:[DeviceMessage.make(device: user_device)]
    )

    TestResult.create_and_index(
      core_fields: {
        'assays' => ['condition' => 'man_flu', 'result' => :negative],
        'start_time' => Time.now - 1.month,
        'name' => 'man_flu',
        'status' => 'error'
      },
      device_messages:[DeviceMessage.make(device: user_device)]
    )

    TestResult.create_and_index(
      core_fields: { 'assays' => ['condition' => 'mtb', 'result' => :negative] },
      device_messages:[DeviceMessage.make(device: user_device_two)]
    )

    refresh_index
  end

  describe 'process results and sort by month' do
    before do
      @data = Reports::Errors.process(current_user, nav_context).sort_by_month
    end

    it 'finds 2 tests when scoped to user/site one' do
      count = @data[0].map { |x| x[:values].sum }.sum
      expect(count).to eq(2)
    end

    it 'includes the name of relevant site user' do
      expect(@data[1]).to include(site_user)
    end
  end
end