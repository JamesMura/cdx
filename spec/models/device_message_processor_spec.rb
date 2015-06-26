require "spec_helper"

describe DeviceMessageProcessor, elasticsearch: true do

  def parsed_message(test_id, params={})
    {
      test: {
        indexed: {
          test_id: test_id,
          assay: "mtb",
          custom_fields: {
            concentration: "15%"
          },
          results: [
            {
              result: "positive",
              condition: "mtb"
            }
          ]
        },
        custom: {
          raw_result: "positivo 15%"
        },
        pii: {
          start_time: "2000/1/1 10:00:00"
        }
      },
      sample: {
        indexed: {
          sample_type: "sputum",
          custom_fields: {
            culture_days: "10"
          }
        },
        custom: {
          datagram: "010100011100"
        },
        pii: {
          sample_uid: "abc4002",
          sample_id: "4002",
          collected_at: "2000/1/1 9:00:00"
        }
      },
      patient: {
        indexed: {
          gender: "male",
          custom_fields: {
            hiv: "positive"
          }
        },
        pii: {
          patient_id: "8000",
          dob: "2000/1/1"
        },
        custom: {
          shirt_color: "blue"
        }
      }
    }.recursive_stringify_keys!.with_indifferent_access.deep_merge(params)
  end

  let(:device) {Device.make}

  let(:institution) {device.institution}

  let(:device_message) do
    device_message = DeviceMessage.new(device: device, plain_text_data: '{}')
    device_message.stub(:parsed_messages).and_return([parsed_message("4")])
    device_message.save!
    device_message
  end

  let(:device_message_processor) {DeviceMessageProcessor.new(device_message)}

  def assert_sample_data(sample)
    sample.plain_sensitive_data.should eq({
      sample_uid: "abc4002",
      sample_id: "4002",
      collected_at: "2000/1/1 9:00:00"
    }.recursive_stringify_keys!)

    sample.custom_fields.should eq({
      datagram: "010100011100"
    }.recursive_stringify_keys!)

    sample.indexed_fields.should eq({
      sample_type: "sputum",
      custom_fields: {
        culture_days: "10"
      }
    }.recursive_stringify_keys!)
  end

  def assert_patient_data(patient)
    patient.plain_sensitive_data.should eq({
      patient_id: "8000",
      dob: "2000/1/1"
    }.recursive_stringify_keys!)

    patient.custom_fields.should eq({
      shirt_color: "blue"
    }.recursive_stringify_keys!)

    patient.indexed_fields.should eq({
      gender: "male",
      custom_fields: {
        hiv: "positive"
      }
    }.recursive_stringify_keys!)
  end

  it "should create a sample" do
    device_message_processor.process

    Sample.count.should eq(1)
    sample = Sample.first
    sample.sample_uid_hash.should eq(MessageEncryption.hash "abc4002")
    assert_sample_data(sample)
    assert_patient_data(sample.patient)
  end

  it "should not update existing tests on new sample" do
    device_message_processor.client.should_receive(:bulk).never
    device_message_processor.process

    Sample.count.should eq(1)
  end

  it "should create a test result" do
    device_message_processor.process

    TestResult.count.should eq(1)
    test = TestResult.first
    test.test_id.should eq('4')

    test.plain_sensitive_data.should eq({
      start_time: "2000/1/1 10:00:00"
    }.recursive_stringify_keys!)

    test.custom_fields.should eq({
      raw_result: "positivo 15%"
    }.recursive_stringify_keys!)
  end

  it "should create multiple test results with single sample" do
    device_message.stub(:parsed_messages).and_return([parsed_message("4"), parsed_message("5"), parsed_message("6")])
    device_message_processor.process

    Sample.count.should eq(1)

    TestResult.count.should eq(3)
    TestResult.pluck(:test_id).should =~ ['4', '5', '6']
    TestResult.pluck(:sample_id).should eq([Sample.first.id] * 3)

    all_elasticsearch_tests_for(device.institution).map {|e| e['_source']['sample_uuid']}.should eq([Sample.first.uuid] * 3)
  end

  it "should update sample data and existing test results on new test result" do
    sample_indexed_fields = {
      sample_type: "blood"
    }.recursive_stringify_keys!

    patient_indexed_fields = {
      custom_fields: {
        hiv: "positive"
      }
    }.recursive_stringify_keys!

    patient = Patient.make(uuid: 'def', indexed_fields: patient_indexed_fields, plain_sensitive_data: {patient_id: '8000'}.recursive_stringify_keys!.with_indifferent_access, institution: device_message.institution)

    sample = Sample.make(uuid: 'abc', indexed_fields: sample_indexed_fields, plain_sensitive_data: {sample_uid: 'abc4002'}.recursive_stringify_keys!.with_indifferent_access, institution: device_message.institution, patient: patient)

    test = TestResult.create_and_index({sample_uuid: sample.uuid, test_id: "3", assay: "mtb", custom_fields: {concentration: "15%"}}, {sample: sample, test_id: '3', patient: patient, device: device})
    test = TestResult.create_and_index({sample_uuid: sample.uuid, test_id: "2", assay: "mtb"}, {sample: sample, test_id: '2', patient: patient, device: device})

    refresh_indices institution.elasticsearch_index_name

    device_message_processor.process

    Sample.count.should eq(1)
    Patient.count.should eq(1)
    sample = Sample.first
    assert_sample_data(sample)
    assert_patient_data(sample.patient)

    tests = all_elasticsearch_tests_for(institution)

    tests.map { |test| test["_source"]["sample_type"] }.should eq(['sputum'] * 3)
  end

  it "should update sample data and existing test results on test result update" do
    sample_indexed_fields = {
      sample_type: "blood"
    }.recursive_stringify_keys!

    patient_indexed_fields = {
      custom_fields: {
        hiv: "positive"
      }
    }.recursive_stringify_keys!

    patient = Patient.make(uuid: 'def', indexed_fields: patient_indexed_fields, plain_sensitive_data: {patient_id: '8000'}.recursive_stringify_keys!.with_indifferent_access, institution: device_message.institution)

    sample = Sample.make(uuid: 'abc', indexed_fields: sample_indexed_fields, plain_sensitive_data: {sample_uid: 'abc4002'}.recursive_stringify_keys!.with_indifferent_access, institution: device_message.institution, patient: patient)

    test = TestResult.create_and_index({sample_uuid: sample.uuid, test_id: "4", assay: "mtb", custom_fields: {concentration: "15%"}}, {sample: sample, test_id: '4', patient: patient, device: device})
    test = TestResult.create_and_index({sample_uuid: sample.uuid, test_id: "2", assay: "mtb"}, {sample: sample, test_id: '2', patient: patient, device: device})

    refresh_indices

    device_message_processor.process

    Sample.count.should eq(1)
    Patient.count.should eq(1)
    sample = Sample.first
    assert_sample_data(sample)
    assert_patient_data(sample.patient)

    tests = all_elasticsearch_tests_for(institution)
    tests.map { |test| test["_source"]["sample_type"] }.should eq(['sputum'] * 2)
  end

  it "should not update existing tests if sample data indexed fields did not change" do
    sample_indexed_fields = {
      sample_type: "sputum",
      custom_fields: {
        culture_days: "10"
      }
    }.recursive_stringify_keys!

    patient_indexed_fields = {
      gender: "male",
      custom_fields: {
        hiv: "positive"
      }
    }.recursive_stringify_keys!

    patient = Patient.make(uuid: 'def', indexed_fields: patient_indexed_fields, plain_sensitive_data: {patient_id: '8000'}.recursive_stringify_keys!.with_indifferent_access, institution: device_message.institution)
    sample = Sample.make(uuid: 'abc', indexed_fields: sample_indexed_fields, plain_sensitive_data: {sample_uid: 'abc4002'}.recursive_stringify_keys!.with_indifferent_access, institution: device_message.institution, patient: patient)
    test = TestResult.create_and_index({sample_uuid: sample.uuid, test_id: "4", assay: "mtb", custom_fields: {concentration: "15%"}}, {sample: sample, test_id: '4', patient: patient, device: device})
    test = TestResult.create_and_index({sample_uuid: sample.uuid, test_id: "2", assay: "mtb"}, {sample: sample, test_id: '2', patient: patient, device: device})

    refresh_indices

    device_message_processor.client.should_receive(:bulk).never
    device_message_processor.process

    Sample.count.should eq(1)
    Patient.count.should eq(1)
    sample = Sample.first
    assert_sample_data(sample)
    assert_patient_data(sample.patient)
  end

  it "shouldn't update sample from another institution" do
    sample_indexed_fields = {
      sample_type: "sputum",
      custom_fields: {
        hiv: "positive"
      }
    }
    sample = Sample.make(uuid: 'abc', indexed_fields: sample_indexed_fields, plain_sensitive_data: {sample_uid: 'abc4002'})

    device_message_processor.process

    Sample.count.should eq(2)

    sample.reload

    sample.plain_sensitive_data.should eq({
      sample_uid: 'abc4002'
    })

    sample.indexed_fields.should eq({
      sample_type: "sputum",
      custom_fields: {
        hiv: "positive"
      }
    })
  end

  it "should update tests with the same test_id and different sample_uid" do
    test = TestResult.create_and_index({test_id: "4", custom_fields: {concentration: "10%", foo: "bar"}, results: [
            {
              result: "negative",
              condition: "flu"
            },
            {
              result: "pos",
              condition: "mtb1"
            }
          ]}, { test_id: '4', device: device})

    device_message_processor.process

    Sample.count.should eq(1)

    tests = all_elasticsearch_tests_for(institution)
    tests.size.should eq(1)
    tests.first["_source"]["assay"].should eq("mtb")
    tests.first["_source"]["sample_type"].should eq("sputum")
    tests.first["_source"]["custom_fields"]["concentration"].should eq("15%")
    tests.first["_source"]["custom_fields"]["foo"].should eq("bar")

    TestResult.count.should eq(1)
    TestResult.first.sample_id.should eq(Sample.last.id)
    TestResult.first.custom_fields.should eq({ "raw_result" => "positivo 15%" })
    TestResult.first.plain_sensitive_data.should eq({ "start_time" => "2000/1/1 10:00:00" })
  end

  context 'sample and patient entities' do

    context 'without sample uid' do
      before :each do
        message = parsed_message("4")
        message[:sample][:pii].delete(:sample_uid)
        message[:patient][:pii] = {}
        message[:patient][:custom] = {}
        message[:patient][:indexed] = {}
        device_message.stub(:parsed_messages).and_return([message])
      end

      it 'should store sample data in test if test does not have a sample' do
        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(0)

        test = TestResult.first

        test.plain_sensitive_data[:sample].should eq({
          sample_id: "4002",
          collected_at: "2000/1/1 9:00:00"
        }.recursive_stringify_keys!)

        test.custom_fields[:sample].should eq({
          datagram: "010100011100"
        }.recursive_stringify_keys!)

        test.indexed_fields[:sample].should eq({
          sample_type: "sputum",
          custom_fields: {
            culture_days: "10"
          }
        }.recursive_stringify_keys!)
      end

      it 'should merge sample if test has a sample' do
        sample = Sample.make(uuid: 'abc', indexed_fields: {existing_field: 'a value'}.recursive_stringify_keys!, plain_sensitive_data: {sample_uid: 'abc4002'}.recursive_stringify_keys!, institution: device_message.institution)
        test = TestResult.create_and_index({sample_uuid: sample.uuid, test_id: "4", assay: "mtb"}, {sample: sample, test_id: '4', device: device})

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(1)

        sample = Sample.first

        sample.plain_sensitive_data.should eq({
          sample_uid: "abc4002",
          sample_id: "4002",
          collected_at: "2000/1/1 9:00:00"
        }.recursive_stringify_keys!)

        sample.custom_fields.should eq({
          datagram: "010100011100"
        }.recursive_stringify_keys!)

        sample.indexed_fields.should eq({
          existing_field: "a value",
          sample_type: "sputum",
          custom_fields: {
            culture_days: "10"
          }
        }.recursive_stringify_keys!)
      end
    end

    context 'with sample uid' do
      before :each do
        message = parsed_message("4")
        message[:patient][:pii] = {}
        message[:patient][:custom] = {}
        message[:patient][:indexed] = {}
        device_message.stub(:parsed_messages).and_return([message])
      end

      it 'should extract existing data in test and create the sample entity' do
        indexed_fields = {
          sample: {
            existing_indexed_field: 'existing_indexed_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        custom_fields = {
          sample: {
            existing_custom_field: 'existing_custom_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        plain_sensitive_data = {
          sample: {
            existing_pii_field: 'existing_pii_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        patient = Patient.make(plain_sensitive_data: {patient_id: '8000'}.recursive_stringify_keys!.with_indifferent_access, institution: device_message.institution)

        test = TestResult.create_and_index({test_id: '4', assay: 'mtb'}, {
          sample: nil, test_id: '4', device: device, patient: patient,
          indexed_fields: indexed_fields,
          custom_fields: custom_fields,
          plain_sensitive_data: plain_sensitive_data
        })

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(1)
        test = TestResult.first
        sample = test.sample

        test.patient.should eq(patient)
        sample.patient.should eq(patient)

        sample.plain_sensitive_data.should eq({
          sample_uid: "abc4002",
          sample_id: "4002",
          collected_at: "2000/1/1 9:00:00",
          existing_pii_field: 'existing_pii_field_value'
        }.recursive_stringify_keys!)

        sample.custom_fields.should eq({
          datagram: "010100011100",
          existing_custom_field: 'existing_custom_field_value'
        }.recursive_stringify_keys!)

        sample.indexed_fields.should eq({
          sample_type: "sputum",
          existing_indexed_field: 'existing_indexed_field_value',
          custom_fields: {
            culture_days: "10"
          }
        }.recursive_stringify_keys!)

        test.plain_sensitive_data[:sample].should be_nil
        test.custom_fields[:sample].should be_nil
        test.indexed_fields[:sample].should be_nil
      end

      it 'should extract existing patient data in test into the sample entity' do
        indexed_fields = {
          patient: {
            existing_indexed_field: 'existing_indexed_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        custom_fields = {
          patient: {
            existing_custom_field: 'existing_custom_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        plain_sensitive_data = {
          patient: {
            existing_pii_field: 'existing_pii_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        test = TestResult.create_and_index({test_id: '4', assay: 'mtb'}, {
          sample: nil, test_id: '4', device: device,
          indexed_fields: indexed_fields,
          custom_fields: custom_fields,
          plain_sensitive_data: plain_sensitive_data
        })

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(1)
        test = TestResult.first
        sample = test.sample

        sample.plain_sensitive_data[:patient].should eq({
          existing_pii_field: 'existing_pii_field_value'
        }.recursive_stringify_keys!)

        sample.custom_fields[:patient].should eq({
          existing_custom_field: 'existing_custom_field_value'
        }.recursive_stringify_keys!)

        sample.indexed_fields[:patient].should eq({
          existing_indexed_field: 'existing_indexed_field_value',
        }.recursive_stringify_keys!)
      end

      it 'should merge sample with existing sample if sample uid matches' do
        indexed_fields = {
          existing_field: 'a value'
        }.recursive_stringify_keys!.with_indifferent_access

        plain_sensitive_data  = {
          sample_uid: 'abc4002'
        }.recursive_stringify_keys!.with_indifferent_access

        sample = Sample.make(uuid: 'abc', indexed_fields: indexed_fields, plain_sensitive_data: plain_sensitive_data, institution: device_message.institution)

        TestResult.create_and_index(
          {sample_uuid: sample.uuid, test_id: '4', assay: 'mtb'},
          {sample: sample, test_id: '4', device: device}
        )

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(1)

        sample = TestResult.first.sample

        sample.plain_sensitive_data.should eq({
          sample_uid: "abc4002",
          sample_id: "4002",
          collected_at: "2000/1/1 9:00:00"
        }.recursive_stringify_keys!)

        sample.custom_fields.should eq({
          datagram: "010100011100"
        }.recursive_stringify_keys!)

        sample.indexed_fields.should eq({
          existing_field: "a value",
          sample_type: "sputum",
          custom_fields: {
            culture_days: "10"
          }
        }.recursive_stringify_keys!)
      end

      it 'should create a new sample if the existing sample has a different sample uid' do
        plain_sensitive_data  = {
          sample_uid: 'def9772'
        }.recursive_stringify_keys!.with_indifferent_access

        sample = Sample.make(
          uuid: 'abc',
          plain_sensitive_data: plain_sensitive_data,
          institution: device_message.institution
        )

        TestResult.create_and_index(
          {sample_uuid: sample.uuid, test_id: '4', assay: 'mtb'},
          {sample: sample, test_id: '4', device: device}
        )

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(1)

        sample = TestResult.first.sample

        sample.plain_sensitive_data.should eq({
          sample_uid: "abc4002",
          sample_id: "4002",
          collected_at: "2000/1/1 9:00:00"
        }.recursive_stringify_keys!)

        sample.custom_fields.should eq({
          datagram: "010100011100"
        }.recursive_stringify_keys!)

        sample.indexed_fields.should eq({
          sample_type: "sputum",
          custom_fields: {
            culture_days: "10"
          }
        }.recursive_stringify_keys!)
      end

      it 'should not destroy existing sample if it has other references' do
        plain_sensitive_data  = {
          sample_uid: 'def9772'
        }.recursive_stringify_keys!.with_indifferent_access

        sample = Sample.make(
          uuid: 'abc',
          plain_sensitive_data: plain_sensitive_data,
          institution: device_message.institution
        )

        test_1 = TestResult.create_and_index(
          {sample_uuid: sample.uuid, test_id: '7', assay: 'mtb'},
          {sample: sample, test_id: '7', device: device}
        )

        device_message_processor.process

        test_2 = TestResult.find_by(test_id: '4')

        test_1.reload.sample.sample_uid.should eq('def9772')
        test_2.reload.sample.sample_uid.should eq('abc4002')
      end

      it "should assign existing sample's patient to the test" do
        patient = Patient.make(plain_sensitive_data: {patient_id: '8000'}, institution: device_message.institution)
        Sample.make(plain_sensitive_data: {sample_uid: 'abc4002'}, patient: patient, institution: device_message.institution)

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(1)
        Patient.count.should eq(1)

        test = TestResult.first
        test.patient.should eq(test.sample.patient)
      end

    end

    context 'without patient id' do
      before :each do
        message = parsed_message('4')
        message[:patient][:pii].delete(:patient_id)
        message[:sample][:pii] = {}
        message[:sample][:custom] = {}
        message[:sample][:indexed] = {}
        device_message.stub(:parsed_messages).and_return([message])
      end

      it 'should merge patient into test patient if test has patient but not sample' do
        plain_sensitive_data = {
          patient_id: '8000'
        }.recursive_stringify_keys!.with_indifferent_access

        indexed_fields = {
          existing_indexed_field: 'existing_indexed_field_value'
        }.recursive_stringify_keys!.with_indifferent_access

        patient = Patient.make(
          plain_sensitive_data: plain_sensitive_data,
          indexed_fields: indexed_fields,
          institution: device_message.institution
        )

        TestResult.create_and_index({test_id: '4', assay: 'mtb'}, {
          sample: nil, test_id: '4', device: device, patient: patient
        })

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(0)
        Patient.count.should eq(1)

        patient = TestResult.first.patient

        patient.plain_sensitive_data.should eq({
          patient_id: "8000",
          dob: "2000/1/1"
        }.recursive_stringify_keys!)

        patient.custom_fields.should eq({
          shirt_color: "blue"
        }.recursive_stringify_keys!)

        patient.indexed_fields.should eq({
          existing_indexed_field: 'existing_indexed_field_value',
          gender: "male",
          custom_fields: {
            hiv: "positive"
          }
        }.recursive_stringify_keys!)
      end

      it 'should merge patient into sample patient if sample has patient' do
        plain_sensitive_data = {
          patient_id: '8000'
        }.recursive_stringify_keys!.with_indifferent_access

        indexed_fields = {
          existing_indexed_field: 'existing_indexed_field_value'
        }.recursive_stringify_keys!.with_indifferent_access

        patient = Patient.make(
          plain_sensitive_data: plain_sensitive_data,
          indexed_fields: indexed_fields,
          institution: device_message.institution
        )

        sample = Sample.make(
          plain_sensitive_data: {sample_uid: 'abc4002'},
          institution: device_message.institution,
          patient: patient
        )

        TestResult.create_and_index({test_id: '4', assay: 'mtb'}, {
          sample: sample, test_id: '4', patient: patient, device: device
        })

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(1)
        Patient.count.should eq(1)

        patient = TestResult.first.sample.patient

        patient.plain_sensitive_data.should eq({
          patient_id: "8000",
          dob: "2000/1/1"
        }.recursive_stringify_keys!)

        patient.custom_fields.should eq({
          shirt_color: "blue"
        }.recursive_stringify_keys!)

        patient.indexed_fields.should eq({
          existing_indexed_field: 'existing_indexed_field_value',
          gender: "male",
          custom_fields: {
            hiv: "positive"
          }
        }.recursive_stringify_keys!)
      end

      it 'should store patient data in test if test does not have a sample or patient' do
        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(0)
        Patient.count.should eq(0)

        test = TestResult.first

        test.plain_sensitive_data[:patient].should eq({
          dob: "2000/1/1"
        }.recursive_stringify_keys!)

        test.custom_fields[:patient].should eq({
          shirt_color: "blue"
        }.recursive_stringify_keys!)

        test.indexed_fields[:patient].should eq({
          gender: "male",
          custom_fields: {
            hiv: "positive"
          }
        }.recursive_stringify_keys!)
      end

      it 'should store patient data in sample if sample is present but doest not have a patient' do
        sample = Sample.make(
          plain_sensitive_data: {sample_uid: 'abc4002'},
          institution: device_message.institution
        )

        TestResult.create_and_index({test_id: '4', assay: 'mtb'}, {
          sample: sample, test_id: '4', device: device
        })

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(1)
        Patient.count.should eq(0)

        sample = TestResult.first.sample

        sample.plain_sensitive_data[:patient].should eq({
          dob: "2000/1/1"
        }.recursive_stringify_keys!)

        sample.custom_fields[:patient].should eq({
          shirt_color: "blue"
        }.recursive_stringify_keys!)

        sample.indexed_fields[:patient].should eq({
          gender: "male",
          custom_fields: {
            hiv: "positive"
          }
        }.recursive_stringify_keys!)
      end
    end

    context 'with patient id' do
      before :each do
        message = parsed_message('4')
        message[:sample][:pii] = {}
        message[:sample][:custom] = {}
        message[:sample][:indexed] = {}
        device_message.stub(:parsed_messages).and_return([message])
      end

      it 'should extract existing data in test and create the patient entity' do
        indexed_fields = {
          patient: {
            existing_indexed_field: 'existing_indexed_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        custom_fields = {
          patient: {
            existing_custom_field: 'existing_custom_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        plain_sensitive_data = {
          patient: {
            existing_pii_field: 'existing_pii_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        TestResult.create_and_index({test_id: '4', assay: 'mtb'}, {
          sample: nil, test_id: '4', device: device,
          indexed_fields: indexed_fields,
          custom_fields: custom_fields,
          plain_sensitive_data: plain_sensitive_data
        })

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(0)
        Patient.count.should eq(1)

        patient = TestResult.first.patient

        patient.plain_sensitive_data.should eq({
          patient_id: "8000",
          dob: "2000/1/1",
          existing_pii_field: 'existing_pii_field_value'
        }.recursive_stringify_keys!)

        patient.custom_fields.should eq({
          shirt_color: "blue",
          existing_custom_field: 'existing_custom_field_value'
        }.recursive_stringify_keys!)

        patient.indexed_fields.should eq({
          existing_indexed_field: 'existing_indexed_field_value',
          gender: "male",
          custom_fields: {
            hiv: "positive"
          }
        }.recursive_stringify_keys!)
      end

      it 'should extract existing data in sample and create the patient entity' do
        indexed_fields = {
          patient: {
            existing_indexed_field: 'existing_indexed_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        custom_fields = {
          patient: {
            existing_custom_field: 'existing_custom_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        plain_sensitive_data = {
          sample_uid: 'abc4002',
          patient: {
            existing_pii_field: 'existing_pii_field_value'
          }
        }.recursive_stringify_keys!.with_indifferent_access

        sample = Sample.make(
          plain_sensitive_data: plain_sensitive_data,
          indexed_fields: indexed_fields,
          custom_fields: custom_fields,
          institution: device_message.institution
        )

        TestResult.create_and_index({test_id: '4', assay: 'mtb'}, {
          sample: sample, test_id: '4', device: device
        })

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(1)
        Patient.count.should eq(1)

        patient = TestResult.first.sample.patient

        patient.plain_sensitive_data.should eq({
          patient_id: "8000",
          dob: "2000/1/1",
          existing_pii_field: 'existing_pii_field_value'
        }.recursive_stringify_keys!)

        patient.custom_fields.should eq({
          shirt_color: "blue",
          existing_custom_field: 'existing_custom_field_value'
        }.recursive_stringify_keys!)

        patient.indexed_fields.should eq({
          existing_indexed_field: 'existing_indexed_field_value',
          gender: "male",
          custom_fields: {
            hiv: "positive"
          }
        }.recursive_stringify_keys!)
      end

      it 'should merge patient with existing patient if patient id matches' do
        indexed_fields = {
          existing_indexed_field: 'existing_indexed_field_value'
        }.recursive_stringify_keys!.with_indifferent_access

        custom_fields = {
          existing_custom_field: 'existing_custom_field_value'
        }.recursive_stringify_keys!.with_indifferent_access

        plain_sensitive_data = {
          patient_id: '8000',
          existing_pii_field: 'existing_pii_field_value'
        }.recursive_stringify_keys!.with_indifferent_access

        patient = Patient.make(
          plain_sensitive_data: plain_sensitive_data,
          indexed_fields: indexed_fields,
          custom_fields: custom_fields,
          institution: device_message.institution
        )

        TestResult.create_and_index({test_id: '4', assay: 'mtb'}, {
          sample: nil, test_id: '4', device: device, patient: patient
        })

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(0)
        Patient.count.should eq(1)

        patient = TestResult.first.patient

        patient.plain_sensitive_data.should eq({
          patient_id: "8000",
          dob: "2000/1/1",
          existing_pii_field: 'existing_pii_field_value'
        }.recursive_stringify_keys!)

        patient.custom_fields.should eq({
          shirt_color: "blue",
          existing_custom_field: 'existing_custom_field_value'
        }.recursive_stringify_keys!)

        patient.indexed_fields.should eq({
          existing_indexed_field: 'existing_indexed_field_value',
          gender: "male",
          custom_fields: {
            hiv: "positive"
          }
        }.recursive_stringify_keys!)
      end

      it 'should create a new patient if the existing patient has a differente patient id' do
        plain_sensitive_data = {
          patient_id: '9000'
        }.recursive_stringify_keys!.with_indifferent_access

        patient = Patient.make(
          plain_sensitive_data: plain_sensitive_data,
          institution: device_message.institution
        )

        TestResult.create_and_index({test_id: '4', assay: 'mtb'}, {
          sample: nil, test_id: '4', device: device, patient: patient
        })

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(0)
        Patient.count.should eq(1)

        patient = TestResult.first.patient

        patient.plain_sensitive_data.should eq({
          patient_id: "8000",
          dob: "2000/1/1"
        }.recursive_stringify_keys!)

        patient.custom_fields.should eq({
          shirt_color: "blue"
        }.recursive_stringify_keys!)

        patient.indexed_fields.should eq({
          gender: "male",
          custom_fields: {
            hiv: "positive"
          }
        }.recursive_stringify_keys!)
      end

      it 'should not destroy existing patient if it has other references' do
        plain_sensitive_data  = {
          patient_id: '9000'
        }.recursive_stringify_keys!.with_indifferent_access

        patient = Patient.make(
          plain_sensitive_data: plain_sensitive_data,
          institution: device_message.institution
        )

        test_1 = TestResult.create_and_index(
          {test_id: '7', assay: 'mtb'},
          {sample: nil, test_id: '7', device: device, patient: patient}
        )

        device_message_processor.process

        test_2 = TestResult.find_by(test_id: '4')

        test_1.reload.patient.patient_id.should eq('9000')
        test_2.patient.patient_id.should eq('8000')
      end

      it 'should create patient and store reference in test and sample' do
        TestResult.create_and_index({test_id: '4', assay: 'mtb'}, {
          test_id: '4', device: device
        })

        device_message_processor.process

        TestResult.count.should eq(1)
        Sample.count.should eq(1)
        Patient.count.should eq(1)

        test = TestResult.first

        test.patient.should eq(test.sample.patient)
      end
    end

  end

end