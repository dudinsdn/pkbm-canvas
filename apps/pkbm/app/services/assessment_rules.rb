require 'bigdecimal'
class AssessmentRules
  def self.validate!(blueprint)
    raise OperationWriter::Invalid, 'Unit dan instrumen wajib diisi' unless blueprint['units'].is_a?(Array) && blueprint['units'].any? && blueprint['items'].is_a?(Array) && blueprint['items'].any?
    raise OperationWriter::Invalid, 'Judul dan mata pelajaran wajib jelas' unless blueprint['title'].present? && %w[MTK BID].include?(blueprint['subject'])
    keys = blueprint['items'].map { |item| item.fetch('key') }
    raise OperationWriter::Invalid, 'Kunci instrumen harus unik' unless keys.uniq == keys
    blueprint['items'].each do |item|
      raise OperationWriter::Invalid, 'Instrumen harus memiliki asal dan petunjuk' unless %w[source design].include?(item['basis']) && item['instructions'].present?
      raise OperationWriter::Invalid, 'Jenis instrumen tidak dikenal' unless %w[practice assignment tam placement].include?(item['kind'])
      if Array(item['mapping_keys']).include?('MAP-08') && item['kind']!='tam'
        raise OperationWriter::Invalid, 'Unit 1 BId mempertahankan sepuluh bobot satu poin dari sumber' unless Array(item['rubric']).map { |c|c['points'] }==Array.new(10,1)
      end
      if Array(item['mapping_keys']).include?('MAP-09') && item['kind']!='tam'
        raise OperationWriter::Invalid, 'Lima bobot Unit 2 BId harus 2,2,4,1,1' unless Array(item['rubric']).map { |c|c['points'] }==[2,2,4,1,1]
      end
      if item['kind'] == 'tam'
        raise OperationWriter::Invalid, 'TAM BId membutuhkan soal pilihan ganda yang ditelaah' unless blueprint['subject'] == 'BID' && item['questions'].is_a?(Array) && item['questions'].any?
      else
        criteria = item['rubric']
        raise OperationWriter::Invalid, 'Rubrik wajib lengkap' unless criteria.is_a?(Array) && criteria.any? && criteria.all? { |x| x['key'].present? && x['description'].present? && x['points'].is_a?(Numeric) && x['points'] > 0 }
      end
      Array(item['questions']).each do |q|
        raise OperationWriter::Invalid, 'Soal/kunci belum lengkap' unless q['text'].present? && q['answers'].is_a?(Array) && q['answers'].length >= 2 && q['correct'].is_a?(Integer) && q['correct'].between?(0,q['answers'].length-1)
      end
    end
    policy = blueprint.fetch('policy')
    raise OperationWriter::Invalid, 'Ambang Unit 2 belum ditelaah' if blueprint['subject']=='BID' && policy['unit2_threshold_percent']!=70
    raise OperationWriter::Invalid, 'Kebijakan rekap belum ditelaah' unless policy['recap'] == 'per_attempt_no_aggregate'
    raise OperationWriter::Invalid, 'Denominator MTK belum ditetapkan' if blueprint['subject']=='MTK' && policy['assignment_denominator'] != 'sum_published_rubric_maxima'
    true
  end
  def self.score(item, criteria_scores)
    criteria = item.fetch('rubric')
    raise OperationWriter::Invalid, 'Nilai harus mencakup semua kriteria' unless criteria_scores.keys.sort == criteria.map { |x| x.fetch('key') }.sort
    sum = criteria.sum do |criterion|
      score = BigDecimal(criteria_scores.fetch(criterion['key']).to_s)
      maximum = BigDecimal(criterion.fetch('points').to_s)
      raise OperationWriter::Invalid, 'Skor di luar rentang rubrik' unless score.finite? && score >= 0 && score <= maximum
      score
    end
    maximum = criteria.sum { |x| BigDecimal(x.fetch('points').to_s) }
    { points: sum.to_f, maximum: maximum.to_f, percent: (sum / maximum * 100).round(2).to_f }
  rescue ArgumentError
    raise OperationWriter::Invalid, 'Skor harus angka valid'
  end
end
