define([
  'vb/action/actionChain',
  'vb/action/actions',
  'vb/action/actionUtils',
], (
  ActionChain,
  Actions,
  ActionUtils
) => {
  'use strict';

  class filterClass1Chain extends ActionChain {

    /**
     * @param {Object} context
     * @param {Object} params
     * @param {object} params.event
     */
    async run(context, { event }) {
      const { $variables, $functions } = context;

      // Filter table by Item Class 1 and update selectedFilter variable for blue highlight
      const activeFilter = await $functions.filterByItemClass($variables.dashboardData.itemClass1.name);
      $variables.selectedFilter = activeFilter;
    }
  }

  return filterClass1Chain;
});