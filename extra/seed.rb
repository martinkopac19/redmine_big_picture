# Jednorazový seed konfigurácie pre Big Picture.
# Spustiť: rails runner plugins/redmine_big_picture/extra/seed.rb
# Idempotentné – dá sa spustiť opakovane.
#
# Model: Portfolio tracker je dostupný vo VŠETKÝCH aktívnych projektoch,
# takže BP nápad sa dá založiť v ktoromkoľvek projekte a zjaví sa v plugine.

puts '== Big Picture seed =='

# 1) Tracker pre Big Picture (nájde aj premenovaný podľa nastavenia/fallbacku)
tracker = RedmineBigPicture.tracker
unless tracker
  tracker = Tracker.new(name: 'Big Picture')
  tracker.default_status = IssueStatus.find_by(name: 'New') || IssueStatus.first
  tracker.core_fields = Tracker::CORE_FIELDS
  tracker.save!
  puts "  + tracker vytvorený (id=#{tracker.id})"
end
# ulož výber trackera do nastavení pluginu
s = Setting.plugin_redmine_big_picture.to_h
if s['tracker_id'].to_s != tracker.id.to_s
  s['tracker_id'] = tracker.id.to_s
  Setting.plugin_redmine_big_picture = s
end
puts "  = tracker '#{tracker.name}' (id=#{tracker.id}), uložený do nastavení"

# 2) Polia na tasku: Idea owner + Project Manager + Project evidence (odkaz na dokument).
#    Product, Total score a Dev readiness sa na tasku NEzobrazujú
#    (Product zrušený; OPP score a Dev readiness sa spravujú/čítajú len cez Big Picture kartu).
unless IssueCustomField.find_by(name: 'Project evidence')
  IssueCustomField.create!(name: 'Project evidence', field_format: 'link', is_required: false, is_for_all: true)
  puts '  + CF Project evidence vytvorené'
end
['Idea owner', 'Project Manager', 'Project evidence'].each do |n|
  cf = CustomField.find_by(name: n)
  cf.trackers << tracker if cf && !cf.trackers.include?(tracker)
end
io = CustomField.find_by(name: 'Idea owner')
io.update_column(:is_for_all, true) if io && !io.is_for_all?
# odpojiť od trackera polia, ktoré na tasku nechceme
CustomField.where(name: ['Product', 'Total score', 'Dev readiness']).each do |cf|
  cf.trackers.delete(tracker) if cf.trackers.include?(tracker)
end
puts '  = na tracker priradené len Idea owner + Project Manager (Product/OPP/Dev readiness odpojené)'

# 5) Portfolio tracker povoliť vo VŠETKÝCH aktívnych projektoch
added = 0
Project.where(status: Project::STATUS_ACTIVE).find_each do |p|
  unless p.trackers.include?(tracker)
    p.trackers << tracker
    added += 1
  end
end
puts "  = Portfolio tracker zapnutý vo všetkých aktívnych projektoch (+#{added})"

# 6) Statusy zo Sheetu
['Dev prep', 'Ready for dev'].each do |nm|
  IssueStatus.find_or_create_by!(name: nm)
end
puts '  = statusy Dev prep / Ready for dev pripravené'

# 7) Workflow pre tracker Portfolio project – povoliť prechody medzi relevantnými statusmi
status_names = ['New', 'Dev prep', 'In Progress', 'Blocked', 'Closed']
statuses = IssueStatus.where(name: status_names).to_a
created = 0
Role.givable.each do |role|
  statuses.each do |from|
    statuses.each do |to|
      next if from.id == to.id

      wf = WorkflowTransition.find_or_initialize_by(
        tracker_id: tracker.id, role_id: role.id, old_status_id: from.id, new_status_id: to.id
      )
      if wf.new_record?
        wf.save!
        created += 1
      end
    end
  end
end
puts "  = workflow doplnený (+#{created} prechodov)"

# 8) Backfill cache metrík pre existujúce portfólio projekty
n = 0
Issue.where(tracker_id: tracker.id).find_each do |iss|
  iss.bp_recompute!
  n += 1
end
puts "  = prepočítané metriky pre #{n} projektov"

puts '== hotovo =='
