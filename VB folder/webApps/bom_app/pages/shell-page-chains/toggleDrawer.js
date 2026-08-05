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

  class toggleDrawer extends ActionChain {

    /**
     * Toggles the navigation drawer for the page
     * @param {Object} context
     */
    async run(context) {
      const { $application, $flow, $page } = context;

      const callFunctionPageFunctionsToggleDrawerResult = $page.functions.toggleDrawer();
    }
  }

  return toggleDrawer;
});
