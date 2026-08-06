# Self-test výpočtovej logiky Big Picture (regresná ochrana).
# Spustiť: rails runner plugins/redmine_big_picture/extra/selftest.rb
# Vytvorí dočasný projekt "BP SELFTEST", otestuje scenáre a na konci ho zmaže.

require 'ostruct'

$pass = 0
$fail = 0
def check(label, expected, actual)
  if expected == actual
    $pass += 1
    puts "  PASS  #{label}  (=#{actual.inspect})"
  else
    $fail += 1
    puts "  FAIL  #{label}  očakávané #{expected.inspect}, dostal #{actual.inspect}"
  end
end

# Tracker berieme z nastavení pluginu (RedmineBigPicture.tracker pozná aj staré
# názvy). Pevné 'Portfolio project' tu bolo natvrdo a test sa po premenovaní
# trackera na 'Big Picture' vôbec nespustil.
tracker = RedmineBigPicture.tracker or abort('Tracker pre Big Picture chýba – nastavte ho v konfigurácii pluginu alebo spustite seed.')
proj = Project.find(19)
admin = User.where(admin: true).first
User.current = admin
unless Member.exists?(project_id: proj.id, user_id: admin.id)
  Member.create!(project_id: proj.id, user: admin, roles: [Role.givable.first])
end

def cf_id(n) = CustomField.find_by(name: n)&.id&.to_s

issue = Issue.find_by(subject: 'BP SELFTEST', tracker_id: tracker.id)
unless issue
  issue = Issue.new(project: proj, tracker: tracker, author: admin, subject: 'BP SELFTEST',
                    status: IssueStatus.find_by(name: 'New'))
  issue.description = 'selftest'
  vals = {}
  vals[cf_id('Project Manager')] = admin.id.to_s if cf_id('Project Manager')
  vals[cf_id('Idea owner')]      = admin.id.to_s if cf_id('Idea owner')
  issue.custom_field_values = vals
  issue.save!
end

sh = RedmineBigPicture.stakeholders
ph = RedmineBigPicture.phases
issue.bp_ensure_phases!

def set_scores(issue, sh, arr)
  sh.each_with_index do |name, idx|
    r = BpScore.find_or_initialize_by(issue_id: issue.id, stakeholder: name)
    r.score = arr[idx]
    r.scored_by = User.current
    r.save!
  end
  issue.reload
end

def set_phases(issue, ph, states)
  ph.each_with_index do |name, idx|
    r = BpPhase.find_or_initialize_by(issue_id: issue.id, phase: name)
    r.state = states[idx] || 'NO'
    r.save!
  end
  issue.reload
end

puts '== Scenár AGODA (7 platných skóre, 1 no score; 4 NOT APPLY, 2 DONE, 1 NO) =='
set_scores(issue, sh, [2, nil, 2, 2, 1, 3, 2, 2])
set_phases(issue, ph, ['NOT APPLY', 'NOT APPLY', 'DONE', 'NO', 'NOT APPLY', 'NOT APPLY', 'DONE'])
check('Total score = 2.0', 2.0, issue.bp_total_score)
check('Dev readiness = 67', 67, issue.bp_dev_readiness)

puts '== Scenár: žiadne skóre =='
set_scores(issue, sh, Array.new(sh.size))
check('Total score = nil', nil, issue.bp_total_score)

puts '== Scenár: všetky fázy NOT APPLY =='
set_phases(issue, ph, Array.new(ph.size, 'NOT APPLY'))
check('Dev readiness = nil', nil, issue.bp_dev_readiness)

puts '== Scenár: všetky fázy DONE =='
set_phases(issue, ph, Array.new(ph.size, 'DONE'))
check('Dev readiness = 100', 100, issue.bp_dev_readiness)

puts '== Scenár: cache metrík aktualizovaná =='
set_scores(issue, sh, [3, 3, 3, 3, nil, nil, nil, nil])
m = BpProjectMetric.find_by(issue_id: issue.id)
check('cache total_score = 3.0', 3.0, m&.total_score&.to_f)

puts '== Scenár: audit v histórii (journal) =='
before = issue.journals.count
set_scores(issue, sh, [1, 3, 3, 3, nil, nil, nil, nil]) # prvý stakeholder 3 -> 1
check('pribudol aspoň 1 journal', true, issue.reload.journals.count > before)

puts '== Scenár: Hide plugin (skrytie z hlavičky, bez mazania dát) =='
orig_settings = Setting.plugin_redmine_big_picture
begin
  base = Setting.plugin_redmine_big_picture.to_h
  ApplicationController.prepend(Module.new { define_method(:user_setup) { User.current = admin } })
  sess = ActionDispatch::Integration::Session.new(Rails.application)
  # Hľadáme PRESNE odkaz v menu. Pozor: samotný text „Big Picture" je aj názvom
  # trackera v zoznamoch úloh, takže hľadanie podľa textu by vždy našlo zhodu.
  link = ->(html) { html.include?('<a class="big-picture" href="/big_picture">') }

  # Čo musí skrytie prežiť.
  bp_tracker = RedmineBigPicture.tracker
  snapshot = lambda do
    { tracker: bp_tracker&.id,
      issues: (bp_tracker ? Issue.where(tracker_id: bp_tracker.id).count : 0),
      cfs: CustomField.where(name: ['Idea owner', 'Project evidence']).count,
      scores: BpScore.count, phases: BpPhase.count,
      metrics: BpProjectMetric.count, allocations: BpAllocation.count }
  end
  before_snapshot = snapshot.call

  Setting.plugin_redmine_big_picture = base.merge('hidden' => '0')
  sess.get '/my/page'
  check('viditeľný: odkaz je v hlavičke', true, link.call(sess.response.body))

  Setting.plugin_redmine_big_picture = base.merge('hidden' => '1')
  sess.get '/my/page'
  check('skrytý: odkaz zmizol', false, link.call(sess.response.body))
  sess.get '/big_picture'
  check('skrytý: priama URL stále funguje', 200, sess.response.status)
  check('skrytie nič nezmazalo', before_snapshot, snapshot.call)

  Setting.plugin_redmine_big_picture = base.merge('hidden' => '0')
  sess.get '/my/page'
  check('odškrtnuté: odkaz je späť', true, link.call(sess.response.body))
ensure
  Setting.plugin_redmine_big_picture = orig_settings
end

# upratanie
issue.destroy
puts "== VÝSLEDOK: #{$pass} PASS / #{$fail} FAIL =="
