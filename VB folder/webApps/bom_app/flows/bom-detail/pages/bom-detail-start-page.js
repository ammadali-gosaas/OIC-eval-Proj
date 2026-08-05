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
   * Parses the getBomDetail API response into the bomData shape
   * used throughout the BOM Detail page templates.
   * Handles both direct field response and ORDS-wrapped items array.
   */
  PageModule.prototype.parseBomDetailResponse = function(responsePayload) {
    var item = {};

    if (!responsePayload) {
      return this._emptyBomData();
    }

    // Unwrap ORDS items array if present
    if (responsePayload.items && responsePayload.items.length > 0) {
      item = responsePayload.items[0];
    } else if (responsePayload.bom_id || responsePayload.bill_sequence_id) {
      item = responsePayload;
    } else {
      return this._emptyBomData();
    }

    return {
      bomId: item.bom_id || item.bill_sequence_id || '',
      billSequenceId: item.bill_sequence_id || item.bom_id || '',
      orgCode: item.organization_code || item.org_code || '',
      itemNumber: item.item_number || item.assembly_item_number || '',
      structureName: item.structure_name || item.alternate_bom_designator || 'PRIMARY',
      description: item.description || item.bom_description || '',
      effectivityControl: item.effectivity_control || '',
      sourceUpdatedAt: item.source_updated_at || item.last_update_date || '',
      importBatchId: item.import_batch_id || '',
      importedAt: item.imported_at || item.creation_date || '',
      healthScore: item.health_score !== undefined ? item.health_score : 0,
      statusLabel: item.status_label || item.status || ''
    };
  };

  PageModule.prototype._emptyBomData = function() {
    return {
      bomId: '', billSequenceId: '', orgCode: '', itemNumber: '—',
      structureName: '', description: '', effectivityControl: '',
      sourceUpdatedAt: '', importBatchId: '', importedAt: '',
      healthScore: 0, statusLabel: ''
    };
  };

  /**
   * Parses the listBomRuns response into an array for the History tab.
   */
  PageModule.prototype.parseRunsResponse = function(responsePayload) {
    var items = [];
    if (!responsePayload) return items;
    if (Array.isArray(responsePayload)) {
      items = responsePayload;
    } else if (responsePayload.items && Array.isArray(responsePayload.items)) {
      items = responsePayload.items;
    }
    return items;
  };

  /**
   * Extracts the request_id from the createBomAdvisory response.
   */
  PageModule.prototype.extractAdvisoryRequestId = function(responsePayload) {
    if (!responsePayload) return '';
    if (responsePayload.request_id) return responsePayload.request_id;
    if (responsePayload.requestId) return responsePayload.requestId;
    if (responsePayload.items && responsePayload.items[0]) {
      return responsePayload.items[0].request_id || responsePayload.items[0].requestId || '';
    }
    return '';
  };

  /**
   * Parses the getAdvisory response into status/context/mitigation fields.
   */
  PageModule.prototype.parseAdvisoryResponse = function(responsePayload) {
    var result = { status: 'NOT_REQUESTED', context: '', mitigation: '' };
    if (!responsePayload) return result;

    var item = responsePayload;
    if (responsePayload.items && responsePayload.items[0]) {
      item = responsePayload.items[0];
    }

    result.status = item.status || item.advisory_status || 'COMPLETED';
    result.context = item.business_context || item.context || item.advisory_text || '';
    result.mitigation = item.suggested_mitigation || item.mitigation || item.mitigation_action || '';
    return result;
  };

  return PageModule;
});