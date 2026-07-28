class BpPhase < ActiveRecord::Base
  STATES = ['DONE', 'IN PROGRESS', 'NO', 'NOT APPLY'].freeze

  belongs_to :issue

  validates :phase, presence: true
  validate  :phase_known
  validates :state, inclusion: { in: STATES }

  after_commit :bp_sync, on: [:create, :update]

  private

  def phase_known
    return if RedmineBigPicture.phases.include?(phase)

    errors.add(:phase, :inclusion)
  end

  def bp_sync
    bp_audit if saved_change_to_state?
    issue.bp_recompute!
  end

  # Zápis zmeny fázy do histórie tasku.
  def bp_audit
    old, new = saved_change_to_state
    return if old == new

    Journal.create!(
      journalized: issue,
      user: User.current,
      notes: I18n.t(:bp_audit_phase, phase: phase, old: old || '—', new: new)
    )
  end
end
