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

require 'spec_helper'

describe ::API::V3::WorkPackages::Schema::SpecificWorkPackageSchema do
  let(:project) { FactoryGirl.build(:project) }
  let(:type) { FactoryGirl.build(:type) }
  let(:work_package) {
    FactoryGirl.build(:work_package,
                      project: project,
                      type: type)
  }
  let(:current_user) { double('current user') }

  subject { described_class.new(work_package: work_package) }

  it 'has the project set' do
    expect(subject.project).to eql(project)
  end

  it 'has the type set' do
    expect(subject.type).to eql(type)
  end

  describe '#assignable_statuses_for' do
    let(:status_result) { double('status result') }

    before do
      allow(work_package).to receive(:persisted?).and_return(false)
      allow(work_package).to receive(:status_id_changed?).and_return(false)
    end

    it 'calls through to the work package' do
      expect(work_package).to receive(:new_statuses_allowed_to).with(current_user)
        .and_return(status_result)
      expect(subject.assignable_values(:status, current_user)).to eql(status_result)
    end

    context 'changed work package' do
      let(:work_package) {
        double('original work package',
               id: double,
               clone: cloned_wp,
               status: double('wrong status'),
               persisted?: true).as_null_object
      }
      let(:cloned_wp) {
        double('cloned work package',
               new_statuses_allowed_to: status_result)
      }
      let(:stored_status) {
        double('good status')
      }

      before do
        allow(work_package).to receive(:persisted?).and_return(true)
        allow(work_package).to receive(:status_id_changed?).and_return(true)
        allow(Status).to receive(:find_by)
          .with(id: work_package.status_id_was).and_return(stored_status)
      end

      it 'calls through to the cloned work package' do
        expect(cloned_wp).to receive(:status=).with(stored_status)
        expect(cloned_wp).to receive(:new_statuses_allowed_to).with(current_user)
        expect(subject.assignable_values(:status, current_user)).to eql(status_result)
      end
    end
  end

  describe '#available_custom_fields' do
    let(:cf1) { double }
    let(:cf2) { double }
    let(:cf3) { double }

    it 'is expected to return custom fields available in project AND type' do
      allow(type).to receive_message_chain(:custom_fields, :to_a).and_return([cf1, cf2])
      allow(project).to receive_message_chain(:all_work_package_custom_fields, :to_a)
        .and_return([cf2, cf3])

      expect(subject.available_custom_fields).to eql([cf2])
    end

    context 'type missing' do
      let(:type) { nil }
      it 'returns an empty list' do
        allow(project).to receive_message_chain(:all_work_package_custom_fields, :to_a)
          .and_return([cf2, cf3])

        expect(subject.available_custom_fields).to eql([])
      end
    end

    context 'project missing' do
      let(:project) { nil }
      it 'returns an empty list' do
        allow(type).to receive_message_chain(:custom_fields, :to_a).and_return([cf1, cf2])

        expect(subject.available_custom_fields).to eql([])
      end
    end
  end

  describe '#assignable_types' do
    let(:result) { double }

    it 'calls through to the project' do
      expect(project).to receive(:types).and_return(result)
      expect(subject.assignable_values(:type, current_user)).to eql(result)
    end
  end

  describe '#assignable_versions' do
    let(:result) { double }

    it 'calls through to the work package' do
      expect(work_package).to receive(:assignable_versions).and_return(result)
      expect(subject.assignable_values(:version, current_user)).to eql(result)
    end
  end

  describe '#assignable_priorities' do
    let(:active_priority) { FactoryGirl.build(:priority, active: true) }
    let(:inactive_priority) { FactoryGirl.build(:priority, active: false) }

    before do
      active_priority.save!
      inactive_priority.save!
    end

    it 'returns only active priorities' do
      expect(subject.assignable_values(:priority, current_user).size).to be >= 1
      subject.assignable_values(:priority, current_user).each do |priority|
        expect(priority.active).to be_truthy
      end
    end
  end

  describe '#assignable_categories' do
    let(:category) { double('category') }

    before do
      allow(project).to receive(:categories).and_return([category])
    end

    it 'returns all categories of the project' do
      expect(subject.assignable_values(:category, current_user)).to match_array([category])
    end
  end

  describe '#writable?' do
    context 'percentage done' do
      it 'is not writable when inferred by status' do
        allow(Setting).to receive(:work_package_done_ratio).and_return('status')
        expect(subject.writable?(:percentage_done)).to be false
      end

      it 'is not writable when disabled' do
        allow(Setting).to receive(:work_package_done_ratio).and_return('disabled')
        expect(subject.writable?(:percentage_done)).to be false
      end

      it 'is not writable when the work package is a parent' do
        allow(work_package).to receive(:leaf?).and_return(false)
        expect(subject.writable?(:percentage_done)).to be false
      end

      it 'is writable when the work package is a leaf' do
        allow(work_package).to receive(:leaf?).and_return(true)
        expect(subject.writable?(:percentage_done)).to be true
      end
    end

    context 'estimated time' do
      it 'is not writable when the work package is a parent' do
        allow(work_package).to receive(:leaf?).and_return(false)
        expect(subject.writable?(:estimated_time)).to be false
      end

      it 'is writable when the work package is a leaf' do
        allow(work_package).to receive(:leaf?).and_return(true)
        expect(subject.writable?(:estimated_time)).to be true
      end
    end

    context 'start date' do
      it 'is not writable when the work package is a parent' do
        allow(work_package).to receive(:leaf?).and_return(false)
        expect(subject.writable?(:start_date)).to be false
      end

      it 'is writable when the work package is a leaf' do
        allow(work_package).to receive(:leaf?).and_return(true)
        expect(subject.writable?(:start_date)).to be true
      end
    end

    context 'due date' do
      it 'is not writable when the work package is a parent' do
        allow(work_package).to receive(:leaf?).and_return(false)
        expect(subject.writable?(:due_date)).to be false
      end

      it 'is writable when the work package is a leaf' do
        allow(work_package).to receive(:leaf?).and_return(true)
        expect(subject.writable?(:due_date)).to be true
      end
    end
  end
end
