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

  class themeValueChangeHandler extends ActionChain {

    /**
     * @param {Object} context
     * @param {Object} params
     * @param {any} params.value 
     */
    async run(context, { value }) {
       await Actions.fireEvent(context, {
          event: 'application:changeTheme',
          payload: {
            themeName: value,
          },
        });
    }
  }

  return themeValueChangeHandler;
});
