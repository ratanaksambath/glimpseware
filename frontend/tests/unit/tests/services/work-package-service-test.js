//-- copyright
// OpenProject is a project management system.
// Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See doc/COPYRIGHT.rdoc for more details.
//++

/*jshint expr: true*/

describe('WorkPackageService', function() {

  var WorkPackageService,
      stateParams = {};
  beforeEach(module('openproject.api', 'openproject.layout','openproject.services', 'openproject.models'));

  beforeEach(module('openproject.templates', function($provide) {
    var configurationService = {};

    configurationService.isTimezoneSet = sinon.stub().returns(false);

    $provide.constant('$stateParams', stateParams);
    $provide.constant('ConfigurationService', configurationService);
  }));

  beforeEach(inject(function(_WorkPackageService_, _HALAPIResource_){
    WorkPackageService = _WorkPackageService_;
  }));

  describe('performBulkDelete', function() {
    var deleteFunction;

    var workPackages = [
      Factory.build('PlanningElement', {id: 1}),
      Factory.build('PlanningElement', {id: 2})
    ];

    beforeEach(inject(function($http) {
      deleteFunction = sinon.stub($http, 'delete');
    }));

    beforeEach(inject(function($http) {
      var ids = workPackages.map(function(wp) {
        return wp.id;
      });
      WorkPackageService.performBulkDelete(ids);
    }));

    it('sends a delete request', function() {
      expect(deleteFunction).to.have.been.called;
    });

    it('sends the work package ids to the bulk delete action', function() {
      expect(deleteFunction).to.have.been.calledWith('/work_packages/bulk', { params: { 'ids[]': [1, 2] } });
    });
  });

  describe('getWorkPackage', function() {
    var setupFunction;
    var workPackageId = 5;
    var apiResource;
    var apiFetchResource;

    beforeEach(inject(function($q) {
      apiResource = {
        fetch: function() {
          var deferred = $q.defer();
          deferred.resolve({ id: workPackageId } );
          return deferred.promise;
        }
      };
    }));

    beforeEach(inject(function(HALAPIResource) {
      setupFunction = sinon.stub(HALAPIResource, 'setup').returns(apiResource);
    }));

    beforeEach(inject(function() {
      apiFetchResource = WorkPackageService.getWorkPackage(workPackageId);
    }));

    it('makes an api setup call', function() {
      expect(setupFunction).to.have.been.calledWith("/api/v3/work_packages/" + workPackageId);
    });

    it('returns work package', function() {
      apiFetchResource.then(function(wp){
        expect(wp.id).to.equal(workPackageId);
      });
    });
  });
});
