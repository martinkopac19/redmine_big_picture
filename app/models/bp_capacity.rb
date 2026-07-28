class BpCapacity < ActiveRecord::Base
  # Plánovacia kapacita programátora (voľné textové hodnoty, bez výpočtu) – zobrazuje sa v kalendári pri mene.
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true
end
