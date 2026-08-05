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

  PageModule.prototype.setLogsData = function(responsePayload) {
    if (!responsePayload) return [];

    var items = [];
    if (Array.isArray(responsePayload)) {
      items = responsePayload;
    } else if (responsePayload.items && Array.isArray(responsePayload.items)) {
      items = responsePayload.items;
    }

    return items.map(function(item) {
      // 1. Fix Timestamp formatting and target the correct occurred_at field
      var rawTime = item.occurred_at || item.started_at || item.created_at || '';
      var formattedTime = rawTime;
      if (rawTime) {
        var d = new Date(rawTime);
        formattedTime = d.toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit', hour12: true });
      }

      // 2. Convert robotic stage names (e.g., "VALIDATION_COMPLETE" -> "Validation Complete")
      var rawStage = item.stage || item.run_kind || 'UNKNOWN_STAGE';
      var formattedStage = rawStage.replace(/_/g, ' ').replace(/\w\S*/g, function(txt){
         return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
      });

      return {
        correlation_id: item.correlation_id || String(item.log_id || 'N/A'),
        stage: formattedStage,
        source_mode: item.source_mode || 'N/A',
        status: item.status || 'UNKNOWN',
        time: formattedTime,
        details: item.details || item.error_message || 'Diagnostic entry recorded without specific details.'
      };
    });
  };

  return PageModule;
});