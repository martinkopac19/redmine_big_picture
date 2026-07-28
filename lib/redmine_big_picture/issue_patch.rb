module RedmineBigPicture
  module IssuePatch
    extend ActiveSupport::Concern

    included do
      has_many :bp_scores, dependent: :delete_all
      has_many :bp_phases, dependent: :delete_all
      has_many :bp_allocations, dependent: :delete_all
      has_one  :bp_project_metric, dependent: :delete
    end

    # OPP TOTAL SCORE = aritmetický priemer vyplnených skóre stakeholderov.
    # Prázdne / "no score" sa nezapočítavajú (ani do súčtu, ani do počtu).
    def bp_total_score
      vals = bp_scores.where.not(score: nil).pluck(:score)
      return nil if vals.empty?

      (vals.sum.to_f / vals.size).round(2)
    end

    # DEV READINESS % = počet fáz DONE / (počet fáz - počet NOT APPLY).
    def bp_dev_readiness
      phases = bp_phases.to_a
      relevant = phases.reject { |p| p.state == 'NOT APPLY' }
      return nil if relevant.empty?

      done = relevant.count { |p| p.state == 'DONE' }
      (done.to_f / relevant.size * 100).round
    end

    # Zabezpečí, že projekt má všetky (konfigurovateľné) fázy; chýbajúce vytvorí so stavom 'NO'.
    def bp_ensure_phases!
      existing = bp_phases.pluck(:phase)
      (RedmineBigPicture.phases - existing).each do |ph|
        bp_phases.create!(phase: ph, state: 'NO')
      end
    end

    # Prepočíta a uloží metriky do cache tabuľky (Priorities číta z cache, detail počíta naživo).
    # Volá sa z model callbackov (BpScore/BpPhase), takže cache nezamŕza.
    def bp_recompute!
      metric = bp_project_metric || build_bp_project_metric
      metric.total_score = bp_total_score
      metric.dev_readiness = bp_dev_readiness
      metric.save!
    end
  end
end
