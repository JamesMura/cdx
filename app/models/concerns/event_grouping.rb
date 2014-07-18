module EventGrouping
  extend ActiveSupport::Concern

  included do
    def self.query_with_group_by(query, group_by)
      group_by = if (group_by.is_a? String)
        group_by.split ","
      elsif group_by.is_a? Hash
        [group_by]
      else
        Array(group_by)
      end

      group_by = group_by.map do |field|
        classify_group_by_field field
      end

      nested_fields = group_by.select {|f| f[:type] == "nested"}
      non_nested_fields = group_by.reject {|f| f[:type] == "nested"}

      aggregations = Aggregations.new
      aggregations.append non_nested_fields if non_nested_fields.present?
      aggregations.append nested_fields if nested_fields.present?

      event = Elasticsearch.search_all aggregations.to_hash.merge(query: query)
      process_group_by_buckets(event["aggregations"].with_indifferent_access, (non_nested_fields + nested_fields), [], {}, 0)
    end

    def self.classify_group_by_field(field_name)
      field_name = field_name.first if field_name.is_a? Array and field_name.size == 1
      if field_name.is_a? Hash
        if field_name.values[0].is_a? Array
          {type: "range", name: field_name.keys[0], ranges: field_name.values[0]}
        else
          {type: "kind", name: field_name.keys[0], value: field_name.values[0]}
        end
      else
        date_captures = field_name.match /\A(year|month|week|day)\(([^\)]+)\)\Z/
        if date_captures
          {type: "date", name: date_captures[2], interval: date_captures[1]}
        else
          find_in_searchable_fields(field_name)
        end
      end
    end

    def self.find_in_searchable_fields(name)
      find_in_fields name, Event.searchable_fields
    end

    def self.find_in_fields(name, fields=[])
      sub_field_found = nil
      found = fields.detect do |field|
        field[:name].to_s == name.to_s || (field[:type] == "nested" && (sub_field_found = find_in_fields(name, field[:sub_fields])))
      end
      if found
        if found[:type] == "nested"
          {type: "nested", name: found[:name], sub_fields: sub_field_found}
        else
          {type: "flat", name: found[:name]}
        end
      end
    end

    def self.process_group_by_buckets(aggregations, group_by, events, event, doc_count)
      count = aggregations[:count] || aggregations[:kind]
      if count
        if group_by.is_an? Array
          head = group_by.first
          rest = group_by[1..-1]
        else
          head = group_by
          rest = []
        end
        case head[:type]
        when "range"
          process_bucket(rest, events, event, count[:buckets]) do |bucket|
            {head[:name] => [normalize(bucket[:from]), normalize(bucket[:to])]}
          end
        when "date"
          process_bucket(rest, events, event, count[:buckets]) do |bucket|
            {head[:name] => bucket[:key_as_string]}
          end
        when "flat"
          process_bucket(rest, events, event, count[:buckets]) do |bucket|
            {head[:name] => bucket[:key]}
          end
        when "kind"
          locations = Location.where(depth: head[:value]).map &:id
          buckets = count[:buckets].select do |bucket|
            locations.include? bucket[:key]
          end
          process_bucket(rest, events, event, buckets) do |bucket|
            {'location' => bucket[:key]}
          end
        when "nested"
          process_bucket(rest, events, event, (count[:count] || count)[:buckets]) do |bucket|
            {head[:sub_fields][:name] => bucket[:key]}
          end
        else
          raise "Trying to group by a non searchable field"
        end
      else
        event[:count] = doc_count
        events + [event]
      end
    end

    def self.process_bucket(group_by, events, event, buckets)
      buckets.inject events do |events, bucket|
        event = event.merge(yield bucket)
        process_group_by_buckets(bucket, group_by, events, event, bucket[:doc_count])
      end
    end

    def self.normalize(value)
      return value.round if value.is_a? Float and value.round == value
      value
    end
  end
end
