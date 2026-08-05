define([],
  () => {
  'use strict';

  class FragmentModule {
    closeDrawer() {
      document.querySelector('#navDrawer').startOpened = false;
    }
  }

  return FragmentModule;
});