#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

class MyController < ApplicationController
  layout 'my'

  before_filter :require_login

  menu_item :account, only: [:account]
  menu_item :settings, only: [:settings]
  menu_item :password, only: [:password]
  menu_item :access_token, only: [:access_token]
  menu_item :mail_notifications, only: [:mail_notifications]

  DEFAULT_BLOCKS = { 'issuesassignedtome' => :label_assigned_to_me_work_packages,
                     'workpackagesresponsiblefor' => :label_responsible_for_work_packages,
                     'issuesreportedbyme' => :label_reported_work_packages,
                     'issueswatched' => :label_watched_work_packages,
                     'news' => :label_news_latest,
                     'calendar' => :label_calendar,
                     'timelog' => :label_spent_time
           }.freeze

  DEFAULT_LAYOUT = {  'left' => ['issuesassignedtome'],
                      'right' => ['issuesreportedbyme']
                   }.freeze

  verify xhr: true,
         only: [:add_block, :remove_block, :order_blocks]

  def self.available_blocks
    @available_blocks ||= DEFAULT_BLOCKS.merge(Redmine::Views::MyPage::Block.additional_blocks)
  end

  # Show user's page
  def index
    @user = User.current
    @blocks = get_current_layout
    render action: 'page', layout: 'base'
  end
  alias :page :index

  # Edit user's account
  def account
    @user = User.current
    @pref = @user.pref
    write_settings(redirect_to: :account)
  end

  # Edit user's settings
  def settings
    @user = User.current
    write_settings(redirect_to: :settings)
  end

  # Manage user's password
  def password
    @user = User.current  # required by "my" layout
    @username = @user.login
    redirect_if_password_change_not_allowed_for(@user)
  end

  # When making changes here, also check AccountController.change_password
  def change_password
    return render_404 if OpenProject::Configuration.disable_password_login?

    @user = User.current  # required by "my" layout
    @username = @user.login
    return if redirect_if_password_change_not_allowed_for(@user)
    if @user.check_password?(params[:password])
      @user.password = params[:new_password]
      @user.password_confirmation = params[:new_password_confirmation]
      @user.force_password_change = false
      if @user.save
        flash[:notice] = l(:notice_account_password_updated)
        redirect_to action: 'password'
        return
      end
    else
      flash.now[:error] = l(:notice_account_wrong_password)
    end
    # Render the username to hint to a user in case of a forced password change
    render 'my/password', locals: { show_user_name: @user.force_password_change }
  end

  # Administer access tokens
  def access_token
    @user = User.current
  end

  # Configure user's mail notifications
  def mail_notifications
    @user = User.current
    write_settings(redirect_to: :mail_notifications)
  end

  def first_login
    if request.get?
      @user = User.current
      @back_url = url_for(params[:back_url])

    elsif request.post? || request.put?
      User.current.pref.attributes = params[:pref] || {}
      User.current.pref.save

      flash[:notice] = l(:notice_account_updated)
      redirect_back_or_default(controller: '/my', action: 'page')
    end
  end

  # Create a new feeds key
  def reset_rss_key
    if request.post?
      if User.current.rss_token
        User.current.rss_token.destroy
        User.current.reload
      end
      User.current.rss_key
      flash[:notice] = l(:notice_feeds_access_key_reseted)
    end
    redirect_to action: 'access_token'
  end

  def generate_rss_key
    if request.post?
      User.current.rss_key
      flash[:notice] = l(:notice_feeds_access_key_generated)
    end
    redirect_to action: 'access_token'
  end

  # Create a new API key
  def reset_api_key
    if request.post?
      if User.current.api_token
        User.current.api_token.destroy
        User.current.reload
      end
      User.current.api_key
      flash[:notice] = l(:notice_api_access_key_reseted)
    end
    redirect_to action: 'access_token'
  end

  def generate_api_key
    if request.post?
      User.current.api_key
      flash[:notice] = l(:notice_api_access_key_generated)
    end
    redirect_to action: 'access_token'
  end

  # User's page layout configuration
  def page_layout
    @user = User.current
    @blocks = get_current_layout
    @block_options = []
    MyController.available_blocks.each { |k, v| @block_options << [l("my.blocks.#{v}", default: [v, v.to_s.humanize]), k.dasherize] }
  end

  # Add a block to user's page
  # The block is added on top of the page
  # params[:block] : id of the block to add
  def add_block
    block = params[:block].to_s.underscore
    (render nothing: true; return) unless block && (MyController.available_blocks.keys.include? block)
    @user = User.current
    layout = get_current_layout
    # remove if already present in a group
    %w(top left right).each do |f| (layout[f] ||= []).delete block end
    # add it on top
    layout['top'].unshift block
    @user.pref[:my_page_layout] = layout
    @user.pref.save
    render partial: 'block', locals: { user: @user, block_name: block }
  end

  # Remove a block to user's page
  # params[:block] : id of the block to remove
  def remove_block
    block = params[:block].to_s.underscore
    @user = User.current
    # remove block in all groups
    layout = get_current_layout
    %w(top left right).each do |f| (layout[f] ||= []).delete block end
    @user.pref[:my_page_layout] = layout
    @user.pref.save
    render nothing: true
  end

  # Change blocks order on user's page
  # params[:group] : group to order (top, left or right)
  # params[:list-(top|left|right)] : array of block ids of the group
  def order_blocks
    group = params[:group]
    @user = User.current
    if group.is_a?(String)
      group_items = (params["list-#{group}"] || []).map(&:underscore)
      if group_items and group_items.is_a? Array
        layout = get_current_layout
        # remove group blocks if they are presents in other groups
        %w(top left right).each do |f|
          layout[f] = (layout[f] || []) - group_items
        end
        layout[group] = group_items
        @user.pref[:my_page_layout] = layout
        @user.pref.save
      end
    end
    render nothing: true
  end

  def default_breadcrumb
    l(:label_my_account)
  end

  private

  def redirect_if_password_change_not_allowed_for(user)
    unless user.change_password_allowed?
      flash[:error] = l(:notice_can_t_change_password)
      redirect_to action: 'account'
      return true
    end
    false
  end

  def write_settings(redirect_to:)
    if request.patch?
      @user.attributes = permitted_params.user
      @user.pref.attributes = params[:pref] || {}
      @user.pref[:no_self_notified] = (params[:no_self_notified] == '1')
      if @user.save
        @user.pref.save
        @user.notified_project_ids =
          (@user.mail_notification == 'selected' ? params[:notified_project_ids] : [])
        set_language_if_valid @user.language
        flash[:notice] = l(:notice_account_updated)
        redirect_to(action: redirect_to)
      end
    end
  end

  helper_method :has_tokens?

  def has_tokens?
    Setting.feeds_enabled? || Setting.rest_api_enabled?
  end

  def get_current_layout
    @user.pref[:my_page_layout] || DEFAULT_LAYOUT.dup
  end
end
