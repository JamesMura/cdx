class Presenters::DstLpaResults
  class << self
    def index_table(dst_lpa_results)
      dst_lpa_results.map do |dst_lpa_result|
        {
          id:                dst_lpa_result.uuid,
          sampleCollectedOn: Extras::Dates::Format.datetime_with_time_zone(dst_lpa_result.sample_collected_on),
          examinedBy:        dst_lpa_result.examined_by,
          resultOn:          Extras::Dates::Format.datetime_with_time_zone(dst_lpa_result.result_on),
          mediaUsed:         Extras::Select.find(DstLpaResult.method_options, dst_lpa_result.media_used),
          serialNumber:      dst_lpa_result.serial_number,
          resultH:           Extras::Select.find(DstLpaResult.dst_lpa_options, dst_lpa_result.results_h),
          resultR:           Extras::Select.find(DstLpaResult.dst_lpa_options, dst_lpa_result.results_r),
          resultE:           Extras::Select.find(DstLpaResult.dst_lpa_options, dst_lpa_result.results_e),
          resultS:           Extras::Select.find(DstLpaResult.dst_lpa_options, dst_lpa_result.results_s),
          resultAmk:         Extras::Select.find(DstLpaResult.dst_lpa_options, dst_lpa_result.results_amk),
          resultKm:          Extras::Select.find(DstLpaResult.dst_lpa_options, dst_lpa_result.results_km),
          resultCm:          Extras::Select.find(DstLpaResult.dst_lpa_options, dst_lpa_result.results_cm),
          resultFq:          Extras::Select.find(DstLpaResult.dst_lpa_options, dst_lpa_result.results_fq),
          viewLink:          Rails.application.routes.url_helpers.requested_test_dst_lpa_result_path(requested_test_id: dst_lpa_result.requested_test.id)
        }
      end
    end
  end
end
