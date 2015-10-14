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

module.exports = function(I18n, WorkPackagesTableService, $window, $timeout, flags, PathHelper){

  return {
    restrict: 'E',
    replace: true,
    templateUrl: '/templates/work_packages/work_packages_table.html',
    scope: {
      projectIdentifier: '=',
      columns: '=',
      rows: '=',
      query: '=',
      countByGroup: '=',
      groupBy: '=',
      groupByColumn: '=',
      displaySums: '=',
      totalSums: '=',
      groupSums: '=',
      activationCallback: '&'
    },
    link: function(scope, element, attributes) {
      var activeSelectionBorderIndex;

      scope.I18n = I18n;
      scope.workPackagesTableData = WorkPackagesTableService.getWorkPackagesTableData();
      scope.workPackagePath = PathHelper.staticWorkPackagePath;

      var topMenuHeight = angular.element('#top-menu').prop('offsetHeight') || 0;
      scope.adaptVerticalPosition = function(event) {
        event.pageY -= topMenuHeight;
      };

      // groupings
      scope.grouped = scope.groupByColumn !== undefined;
      scope.groupExpanded = {};

      scope.$watch('workPackagesTableData.allRowsChecked', function(checked) {
        scope.toggleRowsLabel = checked ? I18n.t('js.button_uncheck_all') : I18n.t('js.button_check_all');
      });

      scope.$watchCollection('columns', function() {
        // force Browser rerender
        element.hide().show(0);

        angular.element($window).trigger('resize');
      });
      scope.$watchCollection('rows', function() {
        // force Browser rerender
        element.hide().show(0);

        angular.element($window).trigger('resize');
      });

      scope.setCheckedStateForAllRows = function(state) {
        WorkPackagesTableService.setCheckedStateForAllRows(scope.rows, state);
      };

      var groupableColumns = WorkPackagesTableService.getGroupableColumns();
      scope.$watch('query.groupBy', function(groupBy) {
        if (scope.columns) {
          var groupByColumnIndex = groupableColumns.map(function(column){
            return column.name;
          }).indexOf(groupBy);

          scope.groupByColumn = groupableColumns[groupByColumnIndex];
        }
      });

      scope.$watch(function() {
        return flags.isOn('detailsView');
      }, function(detailsEnabled) {
        scope.hideWorkPackageDetails = !detailsEnabled;
      });

      // Thanks to http://stackoverflow.com/a/880518
      function clearSelection() {
        if(document.selection && document.selection.empty) {
          document.selection.empty();
        } else if(window.getSelection) {
          var sel = window.getSelection();
          sel.removeAllRanges();
        }
      }

      function setRowSelectionState(row, selected) {
        activeSelectionBorderIndex = scope.rows.indexOf(row);
        WorkPackagesTableService.setRowSelection(row, selected);
      }

      function mulipleRowsChecked(){
        var counter = 0;
        for (var i = 0, l = scope.rows.length; i<l; i++) {
          if (scope.rows[i].checked) {
            if (++counter === 2) {
              return true;
            }
          }
        }
        return false;
      }

      scope.selectWorkPackage = function(row, $event) {
        if ($event.target.type != 'checkbox') {
          var currentRowCheckState = row.checked;
          var multipleChecked = mulipleRowsChecked();
          var isLink = angular.element($event.target).is('a');

          if (!($event.ctrlKey || $event.shiftKey)) {
            scope.setCheckedStateForAllRows(false);
          }

          if(isLink) {
            return;
          }

          if ($event.shiftKey) {
            clearSelection();
            activeSelectionBorderIndex = WorkPackagesTableService.selectRowRange(scope.rows, row, activeSelectionBorderIndex);
          } else if($event.ctrlKey){
            setRowSelectionState(row, multipleChecked ? true : !currentRowCheckState);
          } else {
            setRowSelectionState(row, multipleChecked ? true : !currentRowCheckState);

            scope.activationCallback({ id: row.object.id, force: false });
          }
        }
      };

      scope.showWorkPackageDetails = function(row) {
        clearSelection();

        scope.setCheckedStateForAllRows(false);

        setRowSelectionState(row, true);

        scope.activationCallback({ id: row.object.id, force: true });
      };
    }
  };
};
