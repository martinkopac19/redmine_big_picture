module RedmineBigPicture
  # Predvolené zoznamy (fallback, keď nastavenia nie sú vyplnené).
  DEFAULT_STAKEHOLDERS = ['CEO & CPO', 'CZ & SK', 'CTO', 'PM & UX', 'CC', 'HU', 'PL', 'RO'].freeze
  DEFAULT_PHASES = ['Data analysis', 'Competition analysis', 'Business analysis',
                    'Development analysis', 'Wireframes', 'Prototype testing', 'Redmine issues'].freeze

  module_function

  # Stakeholderi z nastavení pluginu (jeden na riadok), inak defaulty.
  def stakeholders
    parse_setting('stakeholders', DEFAULT_STAKEHOLDERS)
  end

  # Pre-dev fázy z nastavení pluginu (jedna na riadok), inak defaulty.
  def phases
    parse_setting('phases', DEFAULT_PHASES)
  end

  # Tracker pre Big Picture – podľa ID z nastavení pluginu.
  # Fallback (pre spätnú kompatibilitu): tracker s názvom 'Big Picture' alebo 'Portfolio project'.
  def tracker
    id = plugin_settings['tracker_id']
    t = (Tracker.find_by(id: id) if id.present?)
    t || Tracker.find_by(name: 'Big Picture') || Tracker.find_by(name: 'Portfolio project')
  end

  # ID rolí, ktoré považujeme za "programátorov" (z nastavení pluginu).
  def developer_role_ids
    Array(plugin_settings['developer_role_ids']).reject(&:blank?).map(&:to_i)
  end

  # Používatelia do kalendárového selectboxu "programmer".
  # Len aktívni používatelia, ktorí majú niektorú z dev rolí (v hocijakom projekte).
  # Fallback: roly s názvom Developer/Developer-HU; ak nič → všetci aktívni.
  def calendar_users
    role_ids = developer_role_ids
    role_ids = Role.where(name: ['Developer', 'Developer-HU']).pluck(:id) if role_ids.empty?
    return User.active.sorted.to_a if role_ids.empty?

    uids = Member.joins(:member_roles).where(member_roles: { role_id: role_ids }).distinct.pluck(:user_id)
    User.active.where(id: uids).sorted.to_a
  end

  def parse_setting(key, default)
    raw = plugin_settings[key]
    list = raw.to_s.split(/\r?\n/).map(&:strip).reject(&:empty?)
    list.empty? ? default : list
  end

  def plugin_settings
    s = Setting.plugin_redmine_big_picture
    s.is_a?(Hash) ? s : {}
  rescue StandardError
    {}
  end
end
