require 'spec_helper'
require 'policy_spec_helper'

describe DevicesController do
  let(:institution) {Institution.make}
  let(:user) {institution.user}
  let(:device_model) {DeviceModel.make}
  let(:device) {Device.make institution: institution}

  before(:each) {sign_in user}

  context "Index" do
    it "should display index when other user grants admin permission" do
      user2 = User.make
      institution2 = Institution.make user: user2
      institution2.devices.make

      grant user2, user, [Institution.resource_name, Device.resource_name], "*"

      get :index, institution_id: institution2.id
    end
  end

  context "Update" do
    it "device is successfully updated if name is provided" do
      d = Device.find(device.id)
      d.name.should_not eq("New device")

      patch :update, {"institution_id" => institution.id, "id" => device.id, "device" => {"name" => "New device"}}

      d = Device.find(device.id)
      d.name.should eq("New device")
    end

    it "device is not updated if name is not provided" do
      d = Device.find(device.id)
      d.name.should eq(device.name)

      patch :update, {"institution_id" => institution.id, "id" => device.id, "device" => {"name" => ""}}

      d = Device.find(device.id)
      d.name.should eq(device.name)
    end
  end

  describe "generate_activation_token" do
    before { post :generate_activation_token, {"institution_id" => device.institution_id, "id" => device.id} }
    let(:token) { ActivationToken.find_by(device_id: device.id)  }

    it { token.should_not be_nil }
    it { token.device.should eq(device) }
    it { token.client_id.should eq(device.uuid) }
    it { token.value.should_not be_nil }
  end

end
