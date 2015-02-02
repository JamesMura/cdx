class Subscriber < ActiveRecord::Base
  belongs_to :user
  belongs_to :filter

  serialize :fields, JSON

  validates_presence_of :user
  validates_presence_of :filter
  validates_presence_of :name
  validates_presence_of :url
  validates_presence_of :filter
  validates_presence_of :fields

  def self.notify_all
    Subscriber.find_each do |subscriber|
      subscriber.notify
    end
  end

  def notify
    fields = self.fields
    filter = self.filter.params
    filter["since"] = last_run_at.iso8601
    events = Cdx::Api::Elasticsearch::Query.new(filter).execute["events"]
    now = Time.now
    events.each do |event|
      PoirotRails::Activity.start("Publish event to subscriber #{self.name}") do
        filtered_event = filter_event(event, fields)
        callback_url = URI.parse self.url
        callback_query = Rack::Utils.parse_nested_query(callback_url.query || "")
        merged_query = filtered_event.merge(callback_query)
        callback_url = "#{callback_url.scheme}://#{callback_url.host}:#{callback_url.port}#{callback_url.path}?#{merged_query.to_query}"
        options = {}
        if self.url_user && self.url_password
          options[:user] = self.url_user
          options[:password] = self.url_password
        end
        site = RestClient::Resource.new(callback_url, options)
        site.post "" rescue nil
      end
    end
    self.last_run_at = now
    self.save!
  end

  def filter_event(event, fields)
    merged_event = event.merge Event.find_by_uuid(event['uuid']).decrypt.sensitive_data
    filtered_event = {}
    fields.each do |field|
      case field
      when "result"
        filtered_event["result"] = merged_event["results"].first["result"]
      when "condition"
        filtered_event["condition"] = merged_event["results"].first["condition"]
      else
        filtered_event[field] = merged_event[field]
      end
    end
    filtered_event
  end
end
