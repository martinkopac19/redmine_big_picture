class BigPictureController < ApplicationController
  before_action :require_login
  before_action :authorize_view, only: [:index, :show, :calendar]
  before_action :authorize_manage, only: [:update_score, :update_phase, :update_evidence, :update_capacity, :add_allocation, :move_allocation, :duplicate_allocation, :remove_allocation]

  helper :big_picture

  # Priorities: zoznam portfólio projektov s filtrami, zoradený podľa Total score.
  # Škáluje na stovky projektov – konštantný počet dotazov (žiadne N+1).
  SORT_KEYS = %w[opp ready status].freeze

  def index
    tracker = self.class.portfolio_tracker
    unless tracker
      @groups = {}
      @group_order = []
      @filter = {}
      return
    end

    all = Issue.where(tracker_id: tracker.id).includes(:status, :custom_values).to_a
    ids = all.map(&:id)
    @metrics = BpProjectMetric.where(issue_id: ids).index_by(&:issue_id)
    @cf_ids = {
      product: CustomField.find_by(name: 'Product')&.id,
      idea_owner: CustomField.find_by(name: 'Idea owner')&.id,
      pm: CustomField.find_by(name: 'Project Manager')&.id,
      evidence: CustomField.find_by(name: 'Project evidence')&.id
    }

    user_ids = []
    [@cf_ids[:idea_owner], @cf_ids[:pm]].compact.each do |cfid|
      all.each do |i|
        v = i.custom_values.detect { |cv| cv.custom_field_id == cfid }&.value
        user_ids << v.to_i if v.present?
      end
    end
    @user_names = User.where(id: user_ids.uniq).to_a.index_by(&:id).transform_values(&:name)

    @filter_statuses = all.map(&:status).uniq.sort_by(&:name)
    @filter_users = @user_names.map { |id, name| [name, id] }.sort_by(&:first)

    @filter = {
      q: params[:q].to_s.strip,
      status_ids: Array(params[:status_id]).reject(&:blank?),
      pms: Array(params[:pm]).reject(&:blank?),
      ios: Array(params[:io]).reject(&:blank?),
      min_score: params[:min_score].to_s,
      min_ready: params[:min_ready].to_s,
      pe: params[:pe].to_s
    }
    rows = all.select { |i| passes_filter?(i) }

    @sort = SORT_KEYS.include?(params[:sort]) ? params[:sort] : 'opp'
    @dir = params[:dir] == 'asc' ? 'asc' : 'desc'
    rows = rows.sort_by { |i| sort_key(i) }
    rows.reverse! if @dir == 'desc'

    # grupovanie per Project Manager
    @groups = rows.group_by { |i| pm_name(i) }
    @group_order = @groups.keys.sort_by { |n| n == '—' ? "￿" : n.downcase }
  end

  # Kalendár = editovateľná mriežka: programátori grupovaní po svojom PM x mesiace.
  # Horizontálny scroll namiesto stránkovania: kotva = minulý mesiac (vždy vľavo),
  # default 8 mesiacov dopredu. Tlačidlo "−" pridá 6 mesiacov do minulosti, "+" 6 do budúcnosti.
  CAL_BASE_FUTURE = 7 # minulý mesiac + 7 = 8 mesiacov v defaulte
  def calendar
    tracker = self.class.portfolio_tracker
    @past = params[:past].to_i.clamp(0, 120)
    @future = params[:future].to_i.clamp(0, 120)
    anchor = Date.today.beginning_of_month << 1 # minulý mesiac
    @anchor_key = anchor.strftime('%Y-%m')
    @start = anchor << @past
    @count = @past + CAL_BASE_FUTURE + @future + 1
    @months = (0...@count).map { |i| @start >> i }
    keys = @months.map { |d| d.strftime('%Y-%m') }

    @cells = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
    @grid = Hash.new { |h, k| h[k] = [] }
    @group_order = []
    @names = {}
    @projects = []
    @cal_users = []
    @capacities = {}
    @can_manage = User.current.allowed_to?(:manage_big_picture, nil, global: true)

    if tracker
      allocs = BpAllocation.where(month: keys).includes(issue: :status).to_a
      pm_cf = CustomField.find_by(name: 'Project Manager')
      by_user = allocs.group_by(&:user_id)

      # tímový PM programátora = najčastejší PM z jeho projektových alokácií
      user_team = {}
      by_user.each do |uid, list|
        pm_ids = list.map { |a| a.issue && pm_cf && a.issue.custom_field_value(pm_cf) }.compact.reject(&:blank?)
        user_team[uid] = pm_ids.group_by(&:itself).max_by { |_, v| v.size }&.first
      end

      ids = (by_user.keys + user_team.values.compact.map(&:to_i)).uniq
      @names = User.where(id: ids).index_by(&:id).transform_values(&:name)
      @capacities = BpCapacity.where(user_id: ids).index_by(&:user_id)
      allocs.each { |a| @cells[a.user_id][a.month] << a }

      by_user.keys.sort_by { |uid| @names[uid].to_s }.each do |uid|
        tid = user_team[uid]
        pm_name = tid.present? ? (@names[tid.to_i] || 'PM') : '—'
        @grid[pm_name] << uid
      end
      @group_order = @grid.keys.sort_by { |n| n == '—' ? "￿" : n.downcase }

      @projects = Issue.where(tracker_id: tracker.id).order(:subject).to_a
      @cal_users = RedmineBigPicture.calendar_users
    end
  end

  def show
    @issue = Issue.find(params[:id])
    @issue.bp_ensure_phases!
    @scores = BpScore.where(issue_id: @issue.id).index_by(&:stakeholder)
    @phases = BpPhase.where(issue_id: @issue.id).index_by(&:phase)
    @allocations = @issue.bp_allocations.includes(:user).order(:month).to_a
    @evidence_cf = CustomField.find_by(name: 'Project evidence')
    @evidence_value = @evidence_cf ? @issue.custom_field_value(@evidence_cf) : nil
  end

  def update_score
    issue = Issue.find(params[:issue_id])
    rec = BpScore.find_or_initialize_by(issue_id: issue.id, stakeholder: params[:stakeholder])
    rec.score = params[:score].presence
    rec.scored_by = User.current
    rec.save!
    respond_metrics(issue)
  end

  def update_phase
    issue = Issue.find(params[:issue_id])
    rec = BpPhase.find_or_initialize_by(issue_id: issue.id, phase: params[:phase])
    rec.state = params[:state]
    rec.save!
    respond_metrics(issue)
  end

  # Uloženie odkazu Project evidence z Big Picture karty (píše sa do natívneho CF issue).
  def update_evidence
    issue = Issue.find(params[:issue_id])
    cf = CustomField.find_by(name: 'Project evidence')
    if cf
      issue.init_journal(User.current)
      issue.custom_field_values = { cf.id.to_s => params[:evidence].to_s }
      issue.save
    end
    redirect_to big_picture_issue_path(issue)
  end

  # Uloženie plánovacej kapacity programátora (voľné textové polia).
  def update_capacity
    if params[:user_id].present?
      cap = BpCapacity.find_or_initialize_by(user_id: params[:user_id])
      cap.content = params[:content]
      cap.save
    end
    respond_to do |format|
      format.json { render json: { ok: true } }
      format.html { redirect_back(fallback_location: big_picture_calendar_path) }
    end
  end

  def add_allocation
    issue_id = params[:issue_id].presence
    title = params[:title].presence
    if params[:user_id].present? && params[:month].present? && (issue_id || title)
      a = if issue_id
            BpAllocation.find_or_initialize_by(issue_id: issue_id, user_id: params[:user_id], month: params[:month])
          else
            BpAllocation.new(user_id: params[:user_id], month: params[:month], title: title)
          end
      a.label = params[:label]
      a.save
    end
    redirect_back(fallback_location: big_picture_calendar_path)
  end

  # Presun chipu do inej bunky (drag&drop): zmení programátora a/alebo mesiac.
  def move_allocation
    a = BpAllocation.find(params[:id])
    a.user_id = params[:user_id] if params[:user_id].present?
    a.month = params[:month] if params[:month].present?
    a.save
    render json: { ok: a.errors.empty? }
  end

  # Duplikuje alokáciu do nasledujúceho mesiaca (tá istá osoba + projekt/text + poznámka).
  def duplicate_allocation
    a = BpAllocation.find(params[:id])
    next_month = (Date.parse("#{a.month}-01") >> 1).strftime('%Y-%m') rescue nil
    if next_month
      dup = if a.issue_id
              BpAllocation.find_or_initialize_by(issue_id: a.issue_id, user_id: a.user_id, month: next_month)
            else
              BpAllocation.new(user_id: a.user_id, month: next_month, title: a.title)
            end
      dup.label = a.label
      dup.save
    end
    redirect_back(fallback_location: big_picture_calendar_path)
  end

  def remove_allocation
    BpAllocation.find(params[:id]).destroy
    respond_to do |format|
      format.json { render json: { ok: true } }
      format.html { redirect_back(fallback_location: big_picture_calendar_path) }
    end
  end

  def self.portfolio_tracker
    RedmineBigPicture.tracker
  end

  private

  def passes_filter?(issue)
    if @filter[:q].present? && !issue.subject.to_s.downcase.include?(@filter[:q].downcase)
      return false
    end
    return false if @filter[:status_ids].any? && !@filter[:status_ids].include?(issue.status_id.to_s)
    return false if @filter[:pms].any? && !@filter[:pms].include?(cv(issue, @cf_ids[:pm]).to_s)
    return false if @filter[:ios].any? && !@filter[:ios].include?(cv(issue, @cf_ids[:idea_owner]).to_s)

    if @filter[:min_score].present?
      ts = @metrics[issue.id]&.total_score&.to_f || -1.0
      return false if ts < @filter[:min_score].to_f
    end
    if @filter[:min_ready].present?
      dr = @metrics[issue.id]&.dev_readiness || -1
      return false if dr < @filter[:min_ready].to_i
    end
    if @filter[:pe] == 'yes'
      return false unless cv(issue, @cf_ids[:evidence]).present?
    elsif @filter[:pe] == 'no'
      return false if cv(issue, @cf_ids[:evidence]).present?
    end
    true
  end

  def sort_key(issue)
    case @sort
    when 'ready'
      [@metrics[issue.id]&.dev_readiness || -1, issue.subject.to_s.downcase]
    when 'status'
      [issue.status.position || 0, issue.subject.to_s.downcase]
    else
      [@metrics[issue.id]&.total_score&.to_f || -1.0, issue.subject.to_s.downcase]
    end
  end

  def pm_name(issue)
    uid = cv(issue, @cf_ids[:pm])
    (uid.present? && @user_names[uid.to_i]) || '—'
  end

  def cv(issue, cf_id)
    return nil unless cf_id

    issue.custom_values.detect { |c| c.custom_field_id == cf_id }&.value
  end

  def respond_metrics(issue)
    issue.reload
    ts = issue.bp_total_score
    dr = issue.bp_dev_readiness
    payload = {
      total_score: ts, total_score_fmt: ts ? format('%.1f', ts) : '–',
      dev_readiness: dr, dev_readiness_fmt: dr ? "#{dr} %" : '–'
    }
    respond_to do |format|
      format.json { render json: payload }
      format.html { redirect_to big_picture_issue_path(issue) }
    end
  end

  def authorize_view
    render_403 unless User.current.allowed_to?(:view_big_picture, nil, global: true)
  end

  def authorize_manage
    render_403 unless User.current.allowed_to?(:manage_big_picture, nil, global: true)
  end
end
