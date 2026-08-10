define(['ojs/ojarraydataprovider'], function(ArrayDataProvider) {
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
   * Helper to safely extract JSON object whether ORDS returns a string or parsed object
   */
  PageModule.prototype._extractDataPayload = function(responsePayload) {
    if (!responsePayload) return null;
    var data = responsePayload;
    if (responsePayload.items && responsePayload.items.length > 0 && responsePayload.items[0].bom_detail_json) {
      try {
        var raw = responsePayload.items[0].bom_detail_json;
        data = (typeof raw === 'string') ? JSON.parse(raw) : raw;
      } catch (e) {
        console.error("Failed to parse bom_detail_json:", e);
        return null;
      }
    }
    return data;
  };

  /**
   * Parses the getBomDetail API response into the bomData shape
   */
  PageModule.prototype.parseBomDetailResponse = function(responsePayload) {
    var dataToParse = this._extractDataPayload(responsePayload) || {};
    var item = dataToParse.bom || (dataToParse.bomId ? dataToParse : {});

    return {
      bomId: item.bomId || item.bom_id || item.BOM_ID || '',
      billSequenceId: item.billSequenceId || item.bill_sequence_id || item.BILL_SEQUENCE_ID || '',
      orgCode: item.organizationCode || item.organization_code || item.ORGANIZATION_CODE || '',
      itemNumber: item.itemNumber || item.item_number || item.ITEM_NUMBER || '—',
      structureName: item.structureName || item.structure_name || item.STRUCTURE_NAME || 'PRIMARY',
      description: item.description || item.bom_description || item.DESCRIPTION || '',
      effectivityControl: item.effectivityControl || item.effectivity_control || item.EFFECTIVITY_CONTROL || '',
      sourceUpdatedAt: item.sourceUpdatedAt || item.source_updated_at || item.SOURCE_UPDATED_AT || '',
      importBatchId: item.importBatchId || item.import_batch_id || item.IMPORT_BATCH_ID || '',
      importedAt: item.importedAt || item.imported_at || item.IMPORTED_AT || '',
      healthScore: item.healthScore !== undefined ? item.healthScore : (item.health_score !== undefined ? item.health_score : 100),
      statusLabel: item.statusLabel || item.status_label || item.STATUS_LABEL || item.status || 'HEALTHY'
    };
  };

  /**
   * Parses components response
   */
  PageModule.prototype.parseComponentsResponse = function(responsePayload) {
    var dataToParse = this._extractDataPayload(responsePayload);
    if (!dataToParse || !dataToParse.components) return [];

    var findings = dataToParse.findings || [];
    var components = dataToParse.components;

    return components.map(function(c) {
      var itemNum = c.componentItemNumber || c.component_item_number || '';
      var hasIssue = findings.some(function(f) {
        return (f.bomComponentId === c.bomComponentId || f.bom_component_id === c.bomComponentId) &&
               (f.issueStatus || f.issue_status) !== 'IGNORED';
      });

      return {
        id: String(c.bomComponentId || c.bom_component_id || itemNum || Math.random()),
        parentItemNumber: c.parentItemNumber || c.parent_item_number || '',
        level: c.bomLevel || c.bom_level || 1,
        itemNumber: itemNum,
        itemClass: c.componentItemClass || c.component_item_class || '',
        qty: c.quantity !== undefined ? c.quantity : 0,
        uom: c.uomCode || c.uom_code || '',
        status: c.itemStatus || c.item_status || 'Active',
        hasIssue: hasIssue,
        componentPath: c.componentPath || c.component_path || ''
      };
    });
  };

  /**
   * Depth-First Hierarchy Data Provider
   */
  PageModule.prototype.getTreeDataProvider = function(flatList) {
    if (!flatList || flatList.length === 0) {
      return new ArrayDataProvider([], { keyAttributes: 'id' });
    }

    var items = JSON.parse(JSON.stringify(flatList));

    var pathMap = {};
    var levelItemMap = {};

    items.forEach(function(item) {
      item.id = String(item.id);
      if (item.componentPath) {
        pathMap[item.componentPath] = item;
      }
      var key = item.level + '::' + item.itemNumber;
      if (!levelItemMap[key]) {
        levelItemMap[key] = item;
      }
    });

    var roots = [];
    items.forEach(function(item) {
      var parent = null;

      if (item.componentPath) {
        var parts = item.componentPath.split('/');
        if (parts.length > 2) {
          parts.pop();
          var parentPath = parts.join('/');
          if (pathMap[parentPath]) {
            parent = pathMap[parentPath];
          }
        }
      }

      if (!parent && item.level > 1 && item.parentItemNumber) {
        var fallbackKey = (item.level - 1) + '::' + item.parentItemNumber;
        if (levelItemMap[fallbackKey]) {
          parent = levelItemMap[fallbackKey];
        }
      }

      if (parent) {
        if (!parent.children) parent.children = [];
        parent.children.push(item);
      } else {
        roots.push(item);
      }
    });

    var flattened = [];
    function traverse(node, depth) {
      var copy = Object.assign({}, node);
      copy.displayLevel = depth;
      delete copy.children;
      flattened.push(copy);

      if (node.children && node.children.length > 0) {
        node.children.forEach(function(child) {
          traverse(child, depth + 1);
        });
      }
    }

    roots.forEach(function(root) {
      traverse(root, root.level || 1);
    });

    var finalList = flattened.length > 0 ? flattened : items;
    return new ArrayDataProvider(finalList, { keyAttributes: 'id' });
  };

  PageModule.prototype.parseScoreDeductions = function(responsePayload) {
    var dataToParse = this._extractDataPayload(responsePayload);
    if (!dataToParse || !dataToParse.findings || dataToParse.findings.length === 0) return [];

    return dataToParse.findings.map(function(f) {
      var deduction = 0;
      var sev = (f.severity || '').toUpperCase();
      var status = (f.issueStatus || f.issue_status || 'OPEN').toUpperCase();

      if (status === 'OPEN' || status === 'REVIEWED') {
        if (sev === 'CRITICAL') deduction = 25;
        else if (sev === 'HIGH') deduction = 10;
        else if (sev === 'WARNING') deduction = 5;
      }

      return {
        rule: f.ruleName || f.rule_name || f.ruleCode || f.rule_code || 'Unknown Rule',
        severity: sev || 'INFO',
        status: status,
        deduction: deduction
      };
    }).filter(function(f) { return f.deduction > 0; });
  };

  PageModule.prototype._emptyBomData = function() {
    return {
      bomId: '', billSequenceId: '', orgCode: '', itemNumber: '—',
      structureName: '', description: '', effectivityControl: '',
      sourceUpdatedAt: '', importBatchId: '', importedAt: '',
      healthScore: 100, statusLabel: 'HEALTHY'
    };
  };

  PageModule.prototype.parseRunsResponse = function(responsePayload) {
    if (!responsePayload) return [];
    if (Array.isArray(responsePayload)) return responsePayload;
    if (responsePayload.items && Array.isArray(responsePayload.items)) return responsePayload.items;
    return [];
  };

  PageModule.prototype.parseAuditTrail = function(responsePayload, allFindingsPayload) {
    var dataToParse = this._extractDataPayload(responsePayload);
    var auditTrail = (dataToParse && dataToParse.auditTrail) ? dataToParse.auditTrail : null;

    // 1. If explicit status review comments exist in database auditTrail, use them
    if (auditTrail && Array.isArray(auditTrail) && auditTrail.length > 0) {
      return auditTrail.map(function(r) {
        return {
          findingId: r.findingId || r.finding_id || '',
          rule: r.ruleName || r.rule_name || r.ruleCode || r.rule_code || 'Validation Rule',
          timestamp: r.reviewedAt || r.reviewed_at ? new Date(r.reviewedAt || r.reviewed_at).toLocaleString() : 'Recent',
          oldStatus: r.oldStatus || r.old_status || 'OPEN',
          newStatus: r.newStatus || r.new_status || 'OPEN',
          user: r.reviewedBy || r.reviewed_by || 'System',
          comment: r.reviewComment || r.review_comment || ''
        };
      });
    }

    // 2. Unpack ALL findings across ALL historical runs
    var list = [];
    if (allFindingsPayload) {
      if (Array.isArray(allFindingsPayload)) {
        list = allFindingsPayload;
      } else if (allFindingsPayload.items && Array.isArray(allFindingsPayload.items)) {
        list = allFindingsPayload.items;
      } else if (typeof allFindingsPayload === 'string') {
        try {
          var parsed = JSON.parse(allFindingsPayload);
          list = parsed.items || (Array.isArray(parsed) ? parsed : []);
        } catch (e) {}
      }
    }

    // 3. Fallback to latest run findings only if list is empty
    if (list.length === 0 && dataToParse && dataToParse.findings) {
      list = dataToParse.findings;
    }

    return list.map(function(r) {
      var reviewTime = r.created_at || r.createdAt || r.reviewed_at || r.reviewedAt;
      return {
        findingId: r.finding_id || r.findingId || '',
        runId: r.run_id || r.runId || '', // <-- Added runId mapping
        rule: r.rule_name || r.ruleName || r.rule_code || r.ruleCode || 'Validation Rule',
        timestamp: reviewTime ? new Date(reviewTime).toLocaleString() : 'Recent',
        oldStatus: r.old_status || r.oldStatus || 'OPEN',
        newStatus: r.issue_status || r.issueStatus || r.new_status || r.newStatus || 'OPEN',
        user: r.reviewed_by || r.reviewedBy || 'System',
        comment: r.review_comment || r.reviewComment || ''
      };
    });
  };

  PageModule.prototype.checkIfEmpty = function(response) {
    if (!response) return true;
    var body = response.body || response;
    var items = body.items || body;
    return !Array.isArray(items) || items.length === 0;
  };

  PageModule.prototype.parseLatestBomAdvisory = function(responsePayload) {
    var result = {
      status: 'NOT_REQUESTED',
      context: 'No global AI Advisory has been generated for this BOM yet.',
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
      } catch (e) {}
    }

    result.context = summary;
    result.mitigation = suggested;
    return result;
  };

  PageModule.prototype.parseLatestFindingAdvisory = function(responsePayload) {
    var result = { status: 'NOT_REQUESTED', context: '', mitigation: '' };
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
      } catch (e) {}
    }

    result.context = summary;
    result.mitigation = suggested;
    return result;
  };

  PageModule.prototype.parseOICResponse = function(responsePayload) {
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
      result.context = summaryRaw;
      result.mitigation = suggestedRaw;
    }

    if (!result.context || result.context.trim() === '') {
      result.context = "Advisory generated but returned no text. Check OIC logs.";
    }

    return result;
  };

  PageModule.prototype.parseFindingAdvisoryResponse = function(responsePayload) {
    return this.parseOICResponse(responsePayload);
  };

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
  
  /**
   * Extracts the specific component item number where the violation occurred
   */
  PageModule.prototype.getFindingComponentItemNumber = function(data) {
    if (!data) return '—';

    // Direct field check
    if (data.component_item_number) return data.component_item_number;
    if (data.componentItemNumber) return data.componentItemNumber;

    // Extract from evidence object / evidence_json string
    var ev = data.evidence_json || data.evidence;
    if (ev) {
      if (typeof ev === 'string') {
        try {
          ev = JSON.parse(ev);
        } catch (e) {}
      }
      if (typeof ev === 'object' && ev !== null) {
        if (ev.componentItemNumber) return ev.componentItemNumber;
        if (ev.component_item_number) return ev.component_item_number;
      }
    }

    // Fallback to top-level assembly item number
    return data.item_number || data.itemNumber || '—';
  };
  /**
   * Extracts the full component hierarchy path for a finding
   */
  PageModule.prototype.getFindingComponentPath = function(data) {
    if (!data) return '—';

    // 1. Direct path fields
    if (data.component_path) return data.component_path;
    if (data.componentPath) return data.componentPath;

    // 2. Extract path from evidence object / evidence_json
    var ev = data.evidence_json || data.evidence;
    if (ev) {
      if (typeof ev === 'string') {
        try { ev = JSON.parse(ev); } catch (e) {}
      }
      if (typeof ev === 'object' && ev !== null) {
        if (ev.componentPath) return ev.componentPath;
        if (ev.component_path) return ev.component_path;

        // Strip leading arrows/spaces if extracting from cyclePath
        if (ev.cyclePath) {
          return ev.cyclePath.replace(/^\s*->\s*/, '').replace(/\s*->\s*/g, '/');
        }

        // Construct clean path directly without "..."
        if (ev.bomItemNumber && ev.componentItemNumber) {
          if (ev.parentItemNumber && ev.parentItemNumber !== ev.bomItemNumber) {
            return ev.bomItemNumber + '/' + ev.parentItemNumber + '/' + ev.componentItemNumber;
          }
          return ev.bomItemNumber + '/' + ev.componentItemNumber;
        }
      }
    }

    // 3. Fallback to top-level assembly item number
    return data.item_number || data.itemNumber || '—';
  };


/**
   * Safely parses evidence_json into a structured object for template rendering
   */
  PageModule.prototype.getParsedEvidence = function(data) {
    if (!data) return null;
    var ev = data.evidence_json || data.evidence;
    if (!ev) return null;

    if (typeof ev === 'string') {
      try {
        ev = JSON.parse(ev);
      } catch (e) {
        return null;
      }
    }
    return typeof ev === 'object' && ev !== null ? ev : null;
  };

  return PageModule;
});