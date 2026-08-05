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
     * @param {Object} context
     */
    async run(context) {
      const { $application } = context;

      const fireApplicationEventToggleDrawerResult = await Actions.fireEvent(context, {
        event: 'application:toggleDrawer',
      });
    }
  }

  return toggleDrawer;
});
