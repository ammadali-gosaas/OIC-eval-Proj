define(['exports'], function(exports) {
  'use strict';

  function PageModule() {}

  PageModule.prototype.loadTailwind = function() {
    if (!document.getElementById('tailwind-cdn')) {
      const script = document.createElement('script');
      script.id = 'tailwind-cdn';
      script.src = 'https://cdn.tailwindcss.com';
      document.head.appendChild(script);
    }
  };

  PageModule.prototype.extractAdvisoryRequestId = function(body) {
    return body && body.advisory_id != null ? String(body.advisory_id) : '';
  };

  PageModule.prototype.parseAdvisoryResponse = function(body) {
    return {
      status: (body && body.ai_status) || 'ERROR',
      context: (body && body.ai_summary) || '',
      mitigation: (body && body.ai_suggested_action) || ''
    };
  };

  // Checks if the findings API response returned zero items
  PageModule.prototype.checkIfEmpty = function(response) {
    if (!response) return true;
    const body = response.body || response;
    const items = body.items || body;
    return !Array.isArray(items) || items.length === 0;
  };

  return PageModule;
});