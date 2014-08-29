require 'spec_helper'

describe ElasticsearchMappingTemplate do
  let(:manifest) do
    definition = %{{
      "metadata" : {
        "version" : "1.0.0",
        "api_version" : "1.0.0",
        "device_models" : ["GX4001"]
      },
      "field_mapping" : [
        {
          "target_field" : "temperature",
          "selector" : "Test.temp",
          "core" : false,
          "type" : "integer",
          "pii" : false,
          "indexed" : true,
          "valid_values" : {
            "range" : {
              "min" : 0,
              "max" : 100
            }
          }
        },
        {
          "target_field" : "results[*].temperature",
          "selector" : "Test.temp",
          "type" : "integer",
          "core" : false,
          "pii" : false,
          "indexed" :true,
          "valid_values" : {
            "range" : {
              "min" : 0,
              "max" : 100
            }
          }
        }
      ]
    }}
    Manifest.create!(definition: definition)
  end

  def default_mapping
    {
      'dynamic' => "strict",
      "dynamic_templates"=>[
        {
          "location_levels"=>{
            "path_match"=>"location.admin_level_*",
            "mapping"=>{"type"=>"integer"}
          }
        }
      ],
      'properties'=> {
        "started_at" => { 'type' => "date", 'index' => 'not_analyzed'},
        "created_at"=>{'type'=>"date", 'index'=>'not_analyzed'},
        "updated_at"=>{'type'=>"date", 'index'=>'not_analyzed'},
        "event_id"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "uuid"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "device_uuid"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "system_user"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "device_serial_number"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "error_code"=>{'type'=>"integer", 'index'=>'not_analyzed'},
        "error_description"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "laboratory_id"=>{'type'=>"integer", 'index'=>'not_analyzed'},
        "location_id"=>{'type'=>"integer", 'index'=>'not_analyzed'},
        "institution_id"=>{'type'=>"integer", 'index'=>'not_analyzed'},
        "parent_locations"=>{'type' => 'integer'},
        "location"=>{'type'=>'nested', 'properties'=>{"admin_level_0"=>{'type'=>'integer'}, "admin_level_1"=>{'type'=>'integer'}, "admin_level_2"=>{'type'=>'integer'}, "admin_level_3"=>{'type'=>'integer'}}},
        "age"=>{'type'=>"integer", 'index'=>'not_analyzed'},
        "assay_name"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "gender"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "ethnicity"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "race"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "race_ethnicity"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "status"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "results"=> {
          'type'=>'nested',
          'properties'=> {
            "result"=> {
              'type'=>"multi_field",
              'fields'=> {
                'analyzed'=> {'type'=> 'string', 'index'=>'analyzed'},
                "result"=>{'type'=>'string', 'index'=>'not_analyzed'}
              }
            },
            "condition"=>{'type'=>"string", 'index'=>'not_analyzed'}
          }
        },
        "test_type"=>{'type'=>"string", 'index'=>'not_analyzed'}
      }
    }
  end

  def default_mapping2
    {
      'dynamic' => "strict",
      "dynamic_templates"=>[
        {
          "location_levels"=>{
            "path_match"=>"location.admin_level_*",
            "mapping"=>{"type"=>"integer"}
          }
        }
      ],
      'properties'=> {
        "started_at" => { 'type' => "date", 'format' => 'dateOptionalTime'},
        "created_at"=>{'type'=>"date", 'format' => 'dateOptionalTime'},
        "updated_at"=>{'type'=>"date", 'format' => 'dateOptionalTime'},
        "event_id"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "uuid"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "device_uuid"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "system_user"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "device_serial_number"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "error_code"=>{'type'=>"integer"},
        "error_description"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "laboratory_id"=>{'type'=>"integer"},
        "location_id"=>{'type'=>"integer"},
        "institution_id"=>{'type'=>"integer"},
        "parent_locations"=>{'type' => 'integer'},
        "location"=>{'type'=>'nested', 'properties'=>{"admin_level_0"=>{'type'=>'integer'}, "admin_level_1"=>{'type'=>'integer'}, "admin_level_2"=>{'type'=>'integer'}, "admin_level_3"=>{'type'=>'integer'}}},
        "age"=>{'type'=>"integer"},
        "assay_name"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "gender"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "ethnicity"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "race"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "race_ethnicity"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "status"=>{'type'=>"string", 'index'=>'not_analyzed'},
        "results"=> {
          'type'=>'nested',
          'properties'=> {
            "result"=> {
              'type'=>"string",
              'index'=>'not_analyzed',
              'fields'=> {
                'analyzed'=> {'type'=> 'string'}
              }
            },
            "condition"=>{'type'=>"string", 'index'=>'not_analyzed'}
          }
        },
        "test_type"=>{'type'=>"string", 'index'=>'not_analyzed'}
      }
    }
  end

  it "should build a template with the default manifest and an specific mapping for each custom manifest" do
    manifest
    ElasticsearchMappingTemplate.new.template.should eq({
      'template'=>"cdp_institution*",
      'mappings'=> {
        '_default_'=> default_mapping,
        'event' => {
          "dynamic_templates"=>[],
          'properties' => {},
          },
        "event_#{manifest.id}" => {
          "dynamic_templates"=>[],
          'properties' => {
            "custom_fields" => {
              'type' => 'nested',
              'properties' => {
                "temperature" => {'type' => "integer", 'index' => 'not_analyzed'}
              }
            },
            "results" => {
              'type' => 'nested',
              'properties' => {
                "custom_fields" => {
                  'type' => 'nested',
                  'properties' => {
                    "temperature" => {'type' => "integer", 'index' => 'not_analyzed'}
                  }
                }
              }
            }
          }
        }
      }
    })
  end

  it "should update the mappings of the existing indices" do
    ElasticsearchMappingTemplate.new.load
    Event.create_or_update_with Device.make, Oj.dump({results: [{result: :positive}]})
    manifest

    mapping = Cdx::Api.client.indices.get_mapping index: Institution.first.elasticsearch_index_name

    event_mapping = default_mapping2
    event_mapping['properties']['custom_fields'] = {
      'type' => 'nested',
      'properties' => {
        "temperature" => {'type' => "integer"}
      },
    }
    event_mapping['properties']['results']['properties']['custom_fields'] = {
      'type' => 'nested',
      'properties' => {
        "temperature" => {'type' => "integer"}
      }
    }

    mapping.should eq({
      "cdp_institution_test_#{Institution.first.id}" => {
        "mappings" => {
          '_default_'=> default_mapping2,
          'event' => default_mapping2,
          "event_#{manifest.id}" => event_mapping
        }
      }
    })
  end
end

