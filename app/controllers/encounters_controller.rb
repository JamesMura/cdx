class EncountersController < ApplicationController
  before_filter :load_institutions

  def new
    return unless authorize_resource(@institutions, CREATE_INSTITUTION_ENCOUNTER)
  end

  def create
    perform_encounter_action do
      prepare_encounter_from_json
      @encounter.save!
    end
  end

  def show
    # TODO add policy for reading encounters
    @encounter = Encounter.find(params[:id])
    @encounter_as_json = as_json_edit(@encounter).attributes!
  end

  def search_sample
    # TODO enforce policy
    institution = institution_by_uuid(params[:institution_uuid])
    samples = Sample.where(institution: institution).where(["entity_id like ?", "%#{params[:q]}%"])
    render json: as_json_samples_search(samples).attributes!
  end

  def search_test
    # TODO enforce policy. filter by institution
    test_results = TestResult.where(["test_id like ?", "%#{params[:q]}%"])
    render json: as_json_test_results_search(test_results).attributes!
  end

  def add_sample
    perform_encounter_action do
      prepare_encounter_from_json
      # TODO enforce policy. filter by institution
      @encounter.add_sample_uniq Sample.find_by(uuid: params[:sample_uuid])
    end
  end

  def add_test
    perform_encounter_action do
      prepare_encounter_from_json
      # TODO enforce policy. filter by institution
      @encounter.add_test_result_uniq TestResult.find_by(uuid: params[:test_uuid])
    end
  end

  private

  def perform_encounter_action
    begin
      yield
    rescue Encounter::MultiplePatientError => e
      render json: { status: :error, message: e.message, encounter: as_json_edit(@encounter).attributes! }
    else
      render json: { status: :ok, encounter: as_json_edit(@encounter).attributes! }
    end
  end

  def load_institutions
    @institutions = check_access(Institution, CREATE_INSTITUTION_ENCOUNTER)
  end

  def institution_by_uuid(uuid)
    @institutions.detect { |i| i.uuid == uuid } # TODO change to query
  end

  def prepare_encounter_from_json
    # TODO enforce policy of samples and test_results while building encounter
    @encounter = Encounter.new

    encounter_param = JSON.parse(params[:encounter])
    @encounter.institution = institution_by_uuid(encounter_param['institution']['uuid'])
    encounter_param['samples'].each do |sample_param|
      @encounter.add_sample_uniq Sample.find_by(uuid: sample_param['uuid'])
    end
    encounter_param['test_results'].each do |test_param|
      @encounter.add_test_result_uniq TestResult.find_by(uuid: test_param['uuid'])
    end
  end

  def as_json_edit(encounter)
    Jbuilder.new do |json|
      json.(encounter, :id)
      json.institution do
        as_json_institution(json, encounter.institution)
      end
      json.patient do
        json.(encounter.patient, :uuid, :plain_sensitive_data) # TODO enforce policy
      end
      json.samples encounter.samples do |json, sample|
        as_json_sample(json, sample)
      end
      json.test_results encounter.test_results do |json, test_result|
        as_json_test_result(json, test_result)
      end
    end
  end

  def as_json_samples_search(samples)
    Jbuilder.new do |json|
      json.array! samples do |json, sample|
        as_json_sample(json, sample)
      end
    end
  end

  def as_json_sample(json, sample)
    json.(sample, :uuid, :entity_id)
    json.institution do
      as_json_institution(json, sample.institution)
    end
  end

  def as_json_test_results_search(test_results)
    Jbuilder.new do |json|
      json.array! test_results do |json, test|
        as_json_test_result(json, test)
      end
    end
  end

  def as_json_test_result(json, test_result)
    json.(test_result, :uuid, :test_id)
    json.name test_result.core_fields[TestResult::NAME_FIELD]
    json.device do
      json.name test_result.device.name
    end
  end

  def as_json_institution(json, institution)
    json.(institution, :uuid, :name)
  end
end
