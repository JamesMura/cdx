class Presenters::Devices
  class << self
    def index_table(devices)
      devices.map do |device|
        {
          id:              device.uuid,
          name:            device.name,
          institutionName: format_institution_name(device),
          modelName:       device.device_model.full_name,
          siteName:        format_site_name(device),
          viewLink:        Rails.application.routes.url_helpers.device_path(device.id)
        }
      end
    end

    protected

    def format_institution_name(device)
      return '' unless device.device_model && device.device_model.institution
      device.device_model.institution.name
    end

    def format_site_name(device)
      return '' unless device.site
      device.site.name
    end
  end
end
