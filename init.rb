require_relative 'lib/redmine_big_picture'
require_relative 'lib/redmine_big_picture/issue_patch'

Redmine::Plugin.register :redmine_big_picture do
  name 'Redmine Big Picture'
  author 'Previo / Claude'
  description 'Portfólio a pre-development tracker (Big Picture): skórovanie, Dev Readiness a roadmapa nad parent taskami.'
  version '0.3.1'

  settings default: {
             'hidden' => '0',
             'tracker_id' => '',
             'developer_role_ids' => [],
             'stakeholders' => RedmineBigPicture::DEFAULT_STAKEHOLDERS.join("\n"),
             'phases' => RedmineBigPicture::DEFAULT_PHASES.join("\n")
           },
           partial: 'settings/big_picture'

  project_module :big_picture do
    permission :view_big_picture,
               { big_picture: [:index, :show, :calendar] },
               global: true, read: true
    permission :manage_big_picture,
               { big_picture: [:update_score, :update_phase, :update_evidence, :update_capacity, :add_allocation, :move_allocation, :duplicate_allocation, :remove_allocation] },
               global: true
  end

  # `if` sa vyhodnocuje pri každom renderovaní menu, takže prepnutie "Hide plugin"
  # v konfigurácii platí okamžite — bez restartu Redmine.
  menu :top_menu, :big_picture,
       { controller: 'big_picture', action: 'index' },
       caption: 'Big Picture',
       if: proc {
         !RedmineBigPicture.hidden? &&
           User.current.logged? &&
           User.current.allowed_to?(:view_big_picture, nil, global: true)
       }
end

# Redmine načítava init.rb v rámci `to_prepare`, takže patch aplikujeme priamo tu.
unless Issue.included_modules.include?(RedmineBigPicture::IssuePatch)
  Issue.include(RedmineBigPicture::IssuePatch)
end
