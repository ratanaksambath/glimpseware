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

describe ::API::V3::WorkPackages::WorkPackageCollectionRepresenter do
  let(:self_base_link) { '/api/v3/example' }
  let(:work_packages) { WorkPackage.all }
  let(:user) { FactoryGirl.build_stubbed(:user) }

  let(:query) { {} }
  let(:groups) { nil }
  let(:total_sums) { nil }

  let(:page_parameter) { nil }
  let(:page_size_parameter) { nil }
  let(:default_page_size) { 30 }
  let(:total) { 5 }

  let(:representer) {
    described_class.new(
      work_packages,
      self_base_link,
      query: query,
      groups: groups,
      total_sums: total_sums,
      page: page_parameter,
      per_page: page_size_parameter,
      current_user: user)
  }

  before do
    FactoryGirl.create_list(:work_package, total)
  end

  context 'generation' do
    subject(:collection) { representer.to_json }
    let(:collection_inner_type) { 'WorkPackage' }

    it 'does not render groups' do
      is_expected.not_to have_json_path('groups')
    end

    it 'does not render sums' do
      is_expected.not_to have_json_path('totalSums')
    end

    context 'limited page size' do
      let(:page_size_parameter) { 2 }

      context 'on the first page' do
        it_behaves_like 'offset-paginated APIv3 collection' do
          let(:page) { 1 }
          let(:page_size) { page_size_parameter }
          let(:actual_count) { page_size_parameter }

          it_behaves_like 'links to next page by offset'
        end

        it_behaves_like 'has no link' do
          let(:link) { 'previousByOffset' }
        end
      end

      context 'on the last page' do
        let(:page_parameter) { 3 }

        it_behaves_like 'offset-paginated APIv3 collection' do
          let(:page) { 3 }
          let(:page_size) { page_size_parameter }
          let(:actual_count) { 1 }

          it_behaves_like 'links to previous page by offset'
        end

        it_behaves_like 'has no link' do
          let(:link) { 'nextByOffset' }
        end
      end
    end

    context 'passing a query hash' do
      let(:query) { { a: 'b', b: 'c' } }

      it_behaves_like 'has an untitled link' do
        let(:link) { 'self' }
        let(:href) { '/api/v3/example?a=b&b=c&offset=1&pageSize=30' }
      end
    end

    context 'passing groups' do
      let(:groups) { { custom: 'object' } }

      it 'renders the groups object as json' do
        is_expected.to be_json_eql(groups.to_json).at_path('groups')
      end
    end

    context 'passing sums' do
      let(:total_sums) { { custom: 'object' } }

      it 'renders the groups object as json' do
        is_expected.to be_json_eql(total_sums.to_json).at_path('totalSums')
      end
    end
  end
end
