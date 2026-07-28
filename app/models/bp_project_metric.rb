class BpProjectMetric < ActiveRecord::Base
  # Cache spočítaných metrík projektu (kvôli rýchlemu zoznamu Priorities pri stovkách projektov).
  belongs_to :issue
end
