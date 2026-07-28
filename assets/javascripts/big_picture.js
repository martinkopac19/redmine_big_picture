document.addEventListener('DOMContentLoaded', function () {
  var meta = document.querySelector('meta[name=csrf-token]');
  var token = meta ? meta.content : null;

  function post(url, data, onDone) {
    fetch(url, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'X-CSRF-Token': token,
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams(data).toString()
    }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    }).then(onDone).catch(function (e) {
      console.error(e);
      alert('Uloženie zlyhalo, skúste znova.');
    });
  }

  // --- Skórovanie / fázy (detail projektu) ---
  function readinessColor(pct) {
    if (pct === null || pct === undefined) return '#999';
    if (pct < 34) return '#e53935';
    if (pct < 67) return '#fb8c00';
    return '#4caf50';
  }
  function refreshTiles(m) {
    var ts = document.getElementById('bp-ts');
    var dr = document.getElementById('bp-dr');
    if (ts) ts.textContent = m.total_score_fmt;
    if (dr) { dr.textContent = m.dev_readiness_fmt; dr.style.color = readinessColor(m.dev_readiness); }
  }
  document.querySelectorAll('select.bp-score-select').forEach(function (sel) {
    sel.addEventListener('change', function () {
      post(sel.dataset.url, { issue_id: sel.dataset.issue, stakeholder: sel.dataset.stakeholder, score: sel.value }, refreshTiles);
    });
  });
  document.querySelectorAll('select.bp-phase-select').forEach(function (sel) {
    sel.addEventListener('change', function () {
      sel.className = 'bp-phase-select bp-state-' + sel.value.toLowerCase().replace(/[^a-z]+/g, '-');
      post(sel.dataset.url, { issue_id: sel.dataset.issue, phase: sel.dataset.phase, state: sel.value }, refreshTiles);
    });
  });

  // --- Kalendár: drag&drop chipov medzi bunkami ---
  var cal = document.querySelector('table.bp-calendar');
  if (cal) {
    var moveBase = cal.dataset.moveBase;
    var dragged = null;

    cal.querySelectorAll('.bp-chip[draggable]').forEach(function (chip) {
      chip.addEventListener('dragstart', function (e) {
        dragged = chip.dataset.allocId;
        e.dataTransfer.effectAllowed = 'move';
      });
      chip.addEventListener('dragend', function () { dragged = null; });
    });

    cal.querySelectorAll('td.bp-cal-cell').forEach(function (cell) {
      cell.addEventListener('dragover', function (e) { e.preventDefault(); cell.classList.add('bp-drop'); });
      cell.addEventListener('dragleave', function () { cell.classList.remove('bp-drop'); });
      cell.addEventListener('drop', function (e) {
        e.preventDefault();
        cell.classList.remove('bp-drop');
        if (!dragged) return;
        post(moveBase + dragged + '/move',
             { user_id: cell.dataset.user, month: cell.dataset.month },
             function () { location.reload(); });
      });
    });
  }

  // --- Kalendár: úvodný horizontálny scroll na kotvu (minulý mesiac) ---
  var scroll = document.querySelector('.bp-cal-scroll');
  if (scroll && cal) {
    var anchorKey = cal.dataset.anchor;
    var anchorTh = anchorKey && cal.querySelector('thead th[data-month="' + anchorKey + '"]');
    var personTh = cal.querySelector('th.bp-cal-person');
    if (anchorTh) {
      var personW = personTh ? personTh.offsetWidth : 0;
      scroll.scrollLeft = anchorTh.offsetLeft - personW;
    }
  }

  // --- Kapacita: auto-rastúca textarea (štart 1 riadok, rastie s obsahom) ---
  function autoGrow(el) {
    el.style.height = 'auto';
    el.style.height = el.scrollHeight + 'px';
  }
  document.querySelectorAll('textarea.bp-autogrow').forEach(function (t) {
    t.addEventListener('input', function () { autoGrow(t); });
  });
  // auto-uloženie kapacity pri zmene (opustenie poľa), bez tlačidla Save
  document.querySelectorAll('textarea.bp-cap-autosave').forEach(function (t) {
    t.addEventListener('change', function () {
      post(t.dataset.url, { user_id: t.dataset.user, content: t.value }, function () {
        // vyčistiť Redmine príznak neuložených zmien (inak beforeunload varuje pri refreshi)
        if (window.jQuery) { window.jQuery(t).removeData('changed'); }
        t.defaultValue = t.value;
        t.classList.add('bp-saved');
        setTimeout(function () { t.classList.remove('bp-saved'); }, 1200);
      });
    });
  });
  // pri otvorení editora prispôsob výšku existujúcemu obsahu (textarea je dovtedy skrytá)
  document.querySelectorAll('details.bp-cap-edit').forEach(function (d) {
    d.addEventListener('toggle', function () {
      if (d.open) {
        d.querySelectorAll('textarea.bp-autogrow').forEach(autoGrow);
      }
    });
  });
});
