class TestOrders::Finder
  attr_reader :filter_query

  def initialize(navigation_context, params)
    @navigation_context = navigation_context
    @params             = params
    set_filter
  end

  protected

  def set_filter
    init_query
    filter_by_navigation_context
    filter_by_checkboxes
    filter_by_encounter_id
    filter_by_status
    filter_by_testing_for
    filter_by_start_time
  end

  def init_query
    @filter_query = Encounter.joins('LEFT OUTER JOIN sites as performing_sites ON performing_sites.id=encounters.performing_site_id')
                      .joins(:institution, :site)
                      .includes(:patient, :user)
  end

  def filter_by_navigation_context
    @filter_query = filter_query.where("institutions.id = ? ", @navigation_context.institution.id) if @navigation_context.institution

    if @navigation_context.exclude_subsites && @navigation_context.site
      @filter_query = filter_query.where("sites.id = ? OR encounters.performing_site_id = ?", @navigation_context.site.id, @navigation_context.site.id)
    elsif !@navigation_context.exclude_subsites && @navigation_context.site
      @filter_query = filter_query.where("sites.id = ? OR encounters.performing_site_id = ? OR sites.parent_id = ?", @navigation_context.site.id, @navigation_context.site.id, @navigation_context.site.id)
    end
  end

  def filter_by_checkboxes
    @filter_query = filter_query.where("encounters.id IN (?)", @params['selectedItems']) if @params['selectedItems'].present?
  end

  def filter_by_encounter_id
    @filter_query = filter_query.where("encounters.uuid = ?", @params['encounter_id']) if @params['encounter_id'].present?
  end

  def filter_by_status
    if @params['status'].present?
      @filter_query = filter_query.where("encounters.status = ?", @params['status'])
    else
      @filter_query = filter_query.where("encounters.status IN (0,1)")
    end
  end

  def filter_by_testing_for
    @filter_query = filter_query.where("encounters.testing_for = ?", @params['testing_for']) if @params['testing_for'].present?
  end

  def filter_by_start_time
    return unless @params['since'].present?
    since_day = start_date + ' 00:00'
    until_day = end_date + ' 23:59'

    @filter_query = filter_query.where('encounters.start_time' => since_day..until_day)
  end

  def start_date
    @params['since']
  end

  def end_date
    @params['until'].present? ? @params['until'] : Date.today.strftime("%Y-%m-%d")
  end
end
