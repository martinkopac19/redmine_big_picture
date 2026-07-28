class BpScore < ActiveRecord::Base
  belongs_to :issue
  belongs_to :scored_by, class_name: 'User', optional: true

  validates :stakeholder, presence: true
  validate  :stakeholder_known
  validates :score, inclusion: { in: 1..3 }, allow_nil: true

  after_commit :bp_sync, on: [:create, :update]

  private

  def stakeholder_known
    return if RedmineBigPicture.stakeholders.include?(stakeholder)

    errors.add(:stakeholder, :inclusion)
  end

  def bp_sync
    bp_audit if saved_change_to_score?
    issue.bp_recompute!
  end

  # Zápis zmeny skóre do histórie tasku (natívny journal → aj notifikácia).
  def bp_audit
    old, new = saved_change_to_score
    return if old == new

    none = I18n.t(:bp_no_score)
    Journal.create!(
      journalized: issue,
      user: scored_by || User.current,
      notes: I18n.t(:bp_audit_score, stakeholder: stakeholder, old: old || none, new: new || none)
    )
  end
end
