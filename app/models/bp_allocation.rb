class BpAllocation < ActiveRecord::Base
  # Alokácia: kto (user) v ktorom mesiaci (month 'YYYY-MM') robí čo.
  # "Čo" = buď portfólio projekt (issue), alebo voľný text (title, napr. "Redmine" / údržba / placeholder).
  # label = malá poznámka pod názvom.
  belongs_to :issue, optional: true
  belongs_to :user

  validates :month, presence: true
  validate :issue_or_title

  def display_title
    issue ? issue.subject : title.to_s
  end

  def free_text?
    issue_id.blank?
  end

  private

  def issue_or_title
    return if issue_id.present? || title.present?

    errors.add(:base, 'Vyplňte projekt alebo voľný text')
  end
end
