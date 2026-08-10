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

  /**
   * Extracts the specific component item number where the violation occurred
   */
  PageModule.prototype.getFindingComponentItemNumber = function(data) {
    if (!data) return '—';

    if (data.component_item_number) return data.component_item_number;
    if (data.componentItemNumber) return data.componentItemNumber;

    var ev = data.evidence_json || data.evidence;
    if (ev) {
      if (typeof ev === 'string') {
        try { ev = JSON.parse(ev); } catch (e) {}
      }
      if (typeof ev === 'object' && ev !== null) {
        if (ev.componentItemNumber) return ev.componentItemNumber;
        if (ev.component_item_number) return ev.component_item_number;
      }
    }

    return data.item_number || data.itemNumber || '—';
  };

  /**
   * Extracts the full component hierarchy path for a finding
   */
  PageModule.prototype.getFindingComponentPath = function(data) {
    if (!data) return '—';

    if (data.component_path) return data.component_path;
    if (data.componentPath) return data.componentPath;

    var ev = data.evidence_json || data.evidence;
    if (ev) {
      if (typeof ev === 'string') {
        try { ev = JSON.parse(ev); } catch (e) {}
      }
      if (typeof ev === 'object' && ev !== null) {
        if (ev.componentPath) return ev.componentPath;
        if (ev.component_path) return ev.component_path;

        if (ev.cyclePath) {
          return ev.cyclePath.replace(/^\s*->\s*/, '').replace(/\s*->\s*/g, '/');
        }

        if (ev.bomItemNumber && ev.componentItemNumber) {
          if (ev.parentItemNumber && ev.parentItemNumber !== ev.bomItemNumber) {
            return ev.bomItemNumber + '/' + ev.parentItemNumber + '/' + ev.componentItemNumber;
          }
          return ev.bomItemNumber + '/' + ev.componentItemNumber;
        }
      }
    }

    return data.item_number || data.itemNumber || '—';
  };

  /**
   * Parses saved finding advisory from DB REST endpoint (findings/:finding_id/advisories)
   */
  PageModule.prototype.parseLatestFindingAdvisory = function(responsePayload) {
    var result = {
      status: 'NOT_REQUESTED',
      context: '',
      mitigation: ''
    };

    if (!responsePayload) return result;

    var items = responsePayload.items || (Array.isArray(responsePayload) ? responsePayload : []);
    if (items.length === 0) return result;

    var latest = items[0];
    result.status = latest.ai_status || latest.aiStatus || 'COMPLETED';

    var summary = latest.ai_summary || latest.aiSummary || '';
    var suggested = latest.ai_suggested_action || latest.aiSuggestedAction || '';

    if (typeof summary === 'string' && summary.trim().startsWith('{')) {
      try {
        var parsed = JSON.parse(summary);
        summary = parsed.ai_summary || summary;
        suggested = parsed.ai_suggested_action || suggested;
      } catch (e) {
        console.log("Finding advisory summary is standard text.");
      }
    }

    result.context = summary;
    result.mitigation = suggested;

    return result;
  };

  /**
   * Parses direct response from FindingAdvisoryService/getFindingAdvisory (OIC)
   */
  PageModule.prototype.parseFindingAdvisoryResponse = function(responsePayload) {
    var result = { status: 'COMPLETED', context: '', mitigation: '' };

    if (!responsePayload) {
      result.status = 'ERROR';
      result.context = 'Received empty response from OIC.';
      return result;
    }

    var summaryRaw = responsePayload.ai_summary || responsePayload.aiSummary || '';
    var suggestedRaw = responsePayload.ai_suggested_action || responsePayload.aiSuggestedAction || '';

    if (responsePayload.items && responsePayload.items.length > 0) {
      summaryRaw = responsePayload.items[0].ai_summary || summaryRaw;
      suggestedRaw = responsePayload.items[0].ai_suggested_action || suggestedRaw;
    }

    try {
      if (typeof summaryRaw === 'string' && summaryRaw.trim().startsWith('{')) {
        var parsed = JSON.parse(summaryRaw);
        result.context = parsed.ai_summary || summaryRaw;
        result.mitigation = parsed.ai_suggested_action || suggestedRaw;
      } else {
        result.context = summaryRaw;
        result.mitigation = suggestedRaw;
      }
    } catch (e) {
      console.error("Safely caught parsing error:", e);
      result.context = summaryRaw;
      result.mitigation = suggestedRaw;
    }

    if (!result.context || result.context.trim() === '') {
      result.context = "Advisory generated but returned no text. Check OIC logs.";
    }

    return result;
  };

  /**
   * Formats advisory text:
   * 1. Strips leading indentation from lines.
   * 2. Places numbered list items (1., 2., 3.) onto clean double newlines without breaking part IDs.
   */
  PageModule.prototype.formatAdvisoryText = function(text) {
    if (!text) return '';

    return text
      .replace(/\r\n/g, '\n')
      .replace(/^[ \t]+/gm, '')
      .replace(/(?<![\w-])([1-9]\d?[\.\)])\s+/g, function(match, listNum, offset) {
        return (offset === 0) ? listNum + ' ' : '\n' + listNum + ' ';
      })
      .trim();
  };

  PageModule.prototype.checkIfEmpty = function(response) {
    if (!response) return true;
    const body = response.body || response;
    const items = body.items || body;
    return !Array.isArray(items) || items.length === 0;
  };

  return PageModule;
});