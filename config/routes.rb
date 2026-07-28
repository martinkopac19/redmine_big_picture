RedmineApp::Application.routes.draw do
  get    'big_picture',                to: 'big_picture#index',             as: 'big_picture'
  get    'big_picture/calendar',       to: 'big_picture#calendar',          as: 'big_picture_calendar'
  post   'big_picture/score',          to: 'big_picture#update_score',      as: 'big_picture_update_score'
  post   'big_picture/phase',          to: 'big_picture#update_phase',      as: 'big_picture_update_phase'
  post   'big_picture/evidence',       to: 'big_picture#update_evidence',   as: 'big_picture_update_evidence'
  post   'big_picture/capacity',       to: 'big_picture#update_capacity',   as: 'big_picture_update_capacity'
  post   'big_picture/allocation',          to: 'big_picture#add_allocation',    as: 'big_picture_add_allocation'
  post   'big_picture/allocation/:id/move', to: 'big_picture#move_allocation',   as: 'big_picture_move_allocation'
  post   'big_picture/allocation/:id/duplicate', to: 'big_picture#duplicate_allocation', as: 'big_picture_duplicate_allocation'
  delete 'big_picture/allocation/:id',      to: 'big_picture#remove_allocation', as: 'big_picture_remove_allocation'
  get    'big_picture/:id',            to: 'big_picture#show',              as: 'big_picture_issue', constraints: { id: /\d+/ }
end
