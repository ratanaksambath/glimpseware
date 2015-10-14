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

module.exports = function(scope, I18n, WatchersService) {
  'use strict';

  var vm = this,
      fetchWatchers = function(loading) {
        vm.error = false;
        vm.loading = angular.isUndefined(loading) ? true : false;
        WatchersService.forWorkPackage(scope.workPackage).then(function(users) {
          vm.watching = users.watching;
          vm.available = users.available;
        }, function() {
          vm.watchers = [];
          vm.available = [];
          vm.error = true;
        }).finally(function() {
          vm.loading = false;
        });
      },
      addWatcher = function(event, watcher) {
        // last stop for this one
        event.stopPropagation();
        watcher.loading = true;
        add(watcher, vm.watching);
        remove(watcher, vm.available);
        WatchersService
          .addForWorkPackage(scope.workPackage, watcher)
          .then(function(watcher) {
            scope.$broadcast('watchers.add.finished', watcher);
          })
          .finally(function() {
            delete watcher.loading;
          });
      },
      removeWatcher = function(event, watcher) {
        event.stopPropagation();
        WatchersService
          .removeFromWorkPackage(scope.workPackage, watcher)
          .then(function(watcher) {
            remove(watcher, vm.watching);
            add(watcher, vm.available);
          });
      };
  // helpers to work with the watchers array
  var remove = function(watcher, arr) {
        var idx = _.findIndex(arr, watcher, equality(watcher));

        if (idx > -1) {
          arr.splice(idx, 1);
        }
      },
      add = function(watcher, arr) {
        var idx = _.findIndex(arr, watcher, equality(watcher));
        if (idx === -1) {
          arr.push(watcher);
        }
      },
      equality = function(firstElement) {
        return function(secondElement) {
          return firstElement.id === secondElement.id;
        };
      };

  vm.watching = [];
  vm.I18n = I18n;
  fetchWatchers();

  scope.$on('watchers.add', addWatcher);
  scope.$on('watchers.remove', removeWatcher);
};
