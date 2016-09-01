module PatientConcern
  extend ActiveSupport::Concern

  included do
    include Entity
    include AutoUUID
    include AutoIdHash
    include Resource
    include DateDistanceHelper
    include WithLocation
    include SiteContained
    include Auditable

    has_many :test_results, dependent: :restrict_with_error
    has_many :samples,      dependent: :restrict_with_error
    has_many :encounters,   dependent: :restrict_with_error
    has_many :comments,     dependent: :destroy
    has_many :audit_logs,   dependent: :destroy
    has_many :episodes,     dependent: :destroy
    has_many :addresses,    dependent: :destroy, :as => :addressable

    validates_presence_of   :institution
    validates_uniqueness_of :entity_id, scope: :institution_id, allow_nil: true
    validate                :entity_id_not_changed

    accepts_nested_attributes_for :addresses

    scope :within, -> (institution_or_site, exclude_subsites = false) {
      if institution_or_site.is_a?(Institution)
        if exclude_subsites
          where(institution: institution_or_site, site: nil)
        else
          where(institution: institution_or_site)
        end
      elsif exclude_subsites
        where("site_id = ? OR id in (#{Encounter.within(institution_or_site, true).select(:patient_id).to_sql})", institution_or_site)
      else
        where("site_prefix LIKE concat(?, '%') OR id in (#{Encounter.within(institution_or_site).select(:patient_id).to_sql})", institution_or_site.prefix)
      end
    }

    validates_inclusion_of :gender, in: Patient.gender_options.map(&:first), allow_blank: true, message: I18n.t('patient.model_form.wrong_gender', gender_values: Patient.gender_options.map(&:first))

    def has_entity_id?
      entity_id_hash.not_nil?
    end

    attribute_field :name, copy: true
    attribute_field :entity_id, field: :id, copy: true
    attribute_field :gender, :email, :phone

    def age
      years_between birth_date_on, Time.now rescue nil
    end

    def multi_address
      address_array = []
      addresses.each do |address|
        address_array << Presenters::Patients.show_full_address(address)
      end
      address_array
    end

    def age_months
      months_between birth_date_on, Time.now rescue nil
    end

    def last_encounter
      @last_encounter || encounters.order(start_time: :desc).first.try(&:start_time)
    end

    def last_encounter=(value)
      @last_encounter = value
    end

    def as_json_card(json)
      json.(self, :id, :name, :age, :age_months, :gender, :address, :multi_address, :phone, :email, :entity_id, :city, :zip_code, :state)
      json.birth_date_on Extras::Dates::Format.datetime_with_time_zone(birth_date_on)
    end

    private

    def entity_id_not_changed
      if entity_id_changed? && self.persisted? && entity_id_was.present?
        errors.add(:entity_id, "can't be changed after assigned")
      end
    end
  end


  class_methods do
    def entity_scope
      "patient"
    end

    def gender_options
      [['male', I18n.t('select.patient.gender_options.male')], ['female', I18n.t('select.patient.gender_options.female')], ['other', I18n.t('select.patient.gender_options.other')]]
    end
  end
end
