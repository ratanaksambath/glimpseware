require 'spec_helper'
require 'features/work_packages/details/inplace_editor/work_package_field'
require 'features/work_packages/work_packages_page'

describe 'new work package', js: true do
  let(:type_task) { FactoryGirl.create(:type_task) }
  let(:types) { [type_task] }
  let(:status) { FactoryGirl.build(:status, is_default: true) }
  let(:priority) { FactoryGirl.build(:priority, is_default: true) }
  let(:project) {
    FactoryGirl.create(:project, types: types)
  }

  let(:user) { FactoryGirl.create :admin }
  let(:work_packages_page) { WorkPackagesPage.new(project) }

  let(:subject) { 'My subject' }
  let(:description) { 'A description of the newly-created work package.' }

  let(:subject_field) { WorkPackageField.new(page, :subject) }
  let(:description_field) { WorkPackageField.new(page, :description) }

  before do
    status.save!
    priority.save!

    login_as(user)
    allow(user.pref).to receive(:warn_on_leaving_unsaved).and_return('0')

    work_packages_page.visit_index
    work_packages_page.click_toolbar_button 'Work packages'

    within '#tasksDropdown' do
      click_link 'Task'
    end
  end

  it 'sucessfully creates a work package' do
    expect(page).to have_selector('.work-packages--details-content.-create-mode')

    find('#work-package-subject input').set(subject)
    find('#work-package-description textarea').set(description)

    within '.work-packages--details-toolbar' do
      click_button 'Save'
    end

    expect(page).to have_selector('.work-packages--details #tabs')
    expect(subject_field.read_state_text).to eq(subject)
    expect(description_field.read_state_text).to eq(description)
  end
end
