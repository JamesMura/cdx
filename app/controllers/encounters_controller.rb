class EncountersController < ApplicationController
  before_filter :load_institutions
  before_filter do
    @main_column_width = 6 unless params[:action] == 'index'
  end

  def new
    return unless authorize_resource(@institutions, CREATE_INSTITUTION_ENCOUNTER)
  end

  def create
    perform_encounter_action do
      prepare_encounter_from_json
      @encounter.save!
    end
  end

  def institutions
    render json: as_json_institution_list(@institutions).attributes!
  end

  def show
    @encounter = Encounter.find(params[:id])
    return unless authorize_resource(@encounter, READ_ENCOUNTER)
    @encounter_as_json = as_json_edit(@encounter).attributes!
    @can_update = has_access?(@encounter, UPDATE_ENCOUNTER)
  end

  def edit
    @encounter = Encounter.find(params[:id])
    return unless authorize_resource(@encounter, UPDATE_ENCOUNTER)
    @encounter_as_json = as_json_edit(@encounter).attributes!
  end

  def update
    perform_encounter_action do
      prepare_encounter_from_json
      return unless authorize_resource(@encounter, UPDATE_ENCOUNTER)
      raise "encounter.id does not match" if params[:id].to_i != @encounter.id
      @encounter.save!
    end
  end

  def search_sample
    @institution = institution_by_uuid(params[:institution_uuid])
    samples = scoped_samples.where(["sample_identifiers.entity_id like ?", "%#{params[:q]}%"])
    render json: as_json_samples_search(samples).attributes!
  end

  def search_test
    @institution = institution_by_uuid(params[:institution_uuid])
    test_results = scoped_test_results.where(["test_id like ?", "%#{params[:q]}%"])
    render json: as_json_test_results_search(test_results).attributes!
  end

  def add_sample
    perform_encounter_action do
      prepare_encounter_from_json
      add_sample_by_uuid params[:sample_uuid]
    end
  end

  def add_test
    perform_encounter_action do
      prepare_encounter_from_json
      add_test_result_by_uuid params[:test_uuid]
    end
  end

  private

  def perform_encounter_action
    begin
      yield
    rescue => e
      render json: { status: :error, message: e.message, encounter: as_json_edit(@encounter).attributes! }
    else
      render json: { status: :ok, encounter: as_json_edit(@encounter).attributes! }
    end
  end

  def load_institutions
    @institutions = check_access(Institution, CREATE_INSTITUTION_ENCOUNTER)
  end

  def institution_by_uuid(uuid)
    @institutions.where(uuid: uuid).first
  end

  def prepare_encounter_from_json
    encounter_param = JSON.parse(params[:encounter])
    @encounter = encounter_param['id'] ? Encounter.find(encounter_param['id']) : Encounter.new

    if @encounter.new_record?
      @institution = institution_by_uuid(encounter_param['institution']['uuid'])
      @encounter.institution = @institution
    else
      @institution = @encounter.institution
    end

    encounter_param['samples'].each do |sample_param|
      add_sample_by_uuid sample_param['uuid']
    end
    encounter_param['test_results'].each do |test_param|
      add_test_result_by_uuid test_param['uuid']
    end

    @encounter.core_fields[Encounter::ASSAYS_FIELD] = encounter_param['assays']
    @encounter.plain_sensitive_data[Encounter::OBSERVATIONS_FIELD] = encounter_param['observations']
  end

  def scoped_samples
    Sample.where("samples.id in (#{authorize_resource(TestResult, QUERY_TEST).joins(:sample_identifier).select('sample_identifiers.sample_id').to_sql})")
              .where(institution: @institution)
              .joins(:sample_identifiers)
  end

  def add_sample_by_uuid(uuid)
    @encounter.add_sample_uniq scoped_samples.find_by("sample_identifiers.uuid" => uuid)
  end

  def scoped_test_results
    authorize_resource(TestResult, QUERY_TEST).where(institution: @institution)
  end

  def add_test_result_by_uuid(uuid)
    @encounter.add_test_result_uniq scoped_test_results.find_by(uuid: uuid)
  end

  def as_json_edit(encounter)
    Jbuilder.new do |json|
      json.(encounter, :id)
      json.assays (encounter.core_fields[Encounter::ASSAYS_FIELD] || [])
      json.observations encounter.plain_sensitive_data[Encounter::OBSERVATIONS_FIELD]

      json.institution do
        as_json_institution(json, encounter.institution)
      end
      json.patient do
        if encounter.patient
          # TODO enforce policy regarding plain_sensitive_data going out
          json.(encounter.patient, :uuid, :plain_sensitive_data)
        else
          json.nil!
        end
      end
      json.samples encounter.samples.uniq do |sample|
        as_json_sample(json, sample)
      end
      json.test_results encounter.test_results.uniq do |test_result|
        as_json_test_result(json, test_result)
      end
    end
  end

  def as_json_samples_search(samples)
    Jbuilder.new do |json|
      json.array! samples do |sample|
        as_json_sample(json, sample)
      end
    end
  end

  def as_json_institution_list(institutions)
    Jbuilder.new do |json|
      json.total_count institutions.size
      json.institutions institutions do |institution|
        as_json_institution(json, institution)
      end
    end
  end

  def as_json_sample(json, sample)
    json.(sample, :uuid, :uuids, :entity_ids)
  end

  def as_json_test_results_search(test_results)
    Jbuilder.new do |json|
      json.array! test_results do |test|
        as_json_test_result(json, test)
      end
    end
  end

  def as_json_test_result(json, test_result)
    json.(test_result, :uuid, :test_id)
    json.name test_result.core_fields[TestResult::NAME_FIELD]
    if test_result.sample
      json.sample_entity_ids test_result.sample.entity_ids
    end
    json.start_time(format_datetime(test_result.core_fields[TestResult::START_TIME_FIELD]))

    json.assays (test_result.core_fields[TestResult::ASSAYS_FIELD] || [])

    if test_result.device.site
      json.site do
        json.name test_result.device.site.name
      end
    end

    json.device do
      json.name test_result.device.name
    end
  end

  def as_json_institution(json, institution)
    json.(institution, :uuid, :name)
  end
end
