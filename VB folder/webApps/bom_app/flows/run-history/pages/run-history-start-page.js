define([], function() {
  'use strict';

  var PageModule = function PageModule() {};

  PageModule.prototype.loadTailwind = function() {
    if (!document.getElementById('tailwind-cdn')) {
      var script = document.createElement('script');
      script.id = 'tailwind-cdn';
      script.src = 'https://cdn.tailwindcss.com';
      document.head.appendChild(script);
    }
  };

  /**
   * Parses the listValidationRuns response body into an array.
   * Handles both direct array and ORDS-wrapped items format.
   */
  PageModule.prototype.setRunsData = function(responsePayload) {
    if (!responsePayload) return [];
    if (Array.isArray(responsePayload)) return responsePayload;
    if (responsePayload.items && Array.isArray(responsePayload.items)) {
      return responsePayload.items;
    }
    return [];
  };

  return PageModule;
});