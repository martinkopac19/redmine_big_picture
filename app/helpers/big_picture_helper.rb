module BigPictureHelper
  # Hodnota (preloadnutého) custom poľa podľa cf_id – bez ďalšieho dotazu do DB.
  def bp_loaded_value(issue, cf_id)
    return nil unless cf_id

    issue.custom_values.detect { |cv| cv.custom_field_id == cf_id }&.value
  end

  # Meno používateľa z user-formát poľa (z preloadnutej mapy mien).
  def bp_loaded_user(issue, cf_id, names)
    v = bp_loaded_value(issue, cf_id)
    v.present? ? names[v.to_i] : nil
  end

  # Farba pozadia štítku statusu (mapovanie na farby zo Sheetu).
  def bp_status_color(status_name)
    case status_name.to_s.downcase
    when 'resolved', 'closed'      then '#4caf50'
    when 'in progress'             then '#8bc34a'
    when 'blocked'                 then '#e53935'
    when 'scored', 'ready for dev' then '#7e57c2'
    when 'dev prep'                then '#fb8c00'
    when 'rejected'                then '#9e9e9e'
    else '#607d8b'
    end
  end

  # Farba readiness (červená -> oranžová -> zelená).
  def bp_readiness_color(pct)
    return '#999' if pct.nil?
    return '#e53935' if pct < 34
    return '#fb8c00' if pct < 67

    '#4caf50'
  end

  # CSS trieda pre stav fázy (napr. 'NOT APPLY' -> 'bp-state-not-apply').
  def bp_state_class(state)
    "bp-state-#{state.to_s.downcase.gsub(/[^a-z]+/, '-')}"
  end

  # Klikateľná hlavička stĺpca so sortovaním (prepína smer + šípka).
  def bp_sort_link(label, key)
    next_dir = (@sort == key && @dir == 'desc') ? 'asc' : 'desc'
    arrow = @sort == key ? (@dir == 'desc' ? ' ▼' : ' ▲') : ''
    link_to((label + arrow).html_safe,
            big_picture_path(request.query_parameters.merge('sort' => key, 'dir' => next_dir)))
  end
end
