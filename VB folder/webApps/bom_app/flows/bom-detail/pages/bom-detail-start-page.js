define(['ojs/ojarraytreedataprovider'], function(ArrayTreeDataProvider) {
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
   */
  PageModule.prototype.parseBomDetailResponse = function(responsePayload) {
    if (!responsePayload) return this._emptyBomData();

    var dataToParse = responsePayload;
    
    // Check if the payload is wrapped in the ORDS stringified 'bom_detail_json'
    if (responsePayload.items && responsePayload.items.length > 0 && responsePayload.items[0].bom_detail_json) {
      try {
        dataToParse = JSON.parse(responsePayload.items[0].bom_detail_json);
      } catch (e) {
        console.error("Failed to parse bom_detail_json:", e);
        return this._emptyBomData();
      }
    }

    var item = {};
    if (dataToParse.bom) {
      item = dataToParse.bom;
    } else if (dataToParse.bomId || dataToParse.bom_id || dataToParse.BOM_ID) {
      item = dataToParse;
    } else {
      return this._emptyBomData();
    }

    // Map values safely
    return {
      bomId: item.bomId || item.bom_id || item.BOM_ID || '',
      billSequenceId: item.billSequenceId || item.bill_sequence_id || item.BILL_SEQUENCE_ID || '',
      orgCode: item.organizationCode || item.organization_code || item.ORGANIZATION_CODE || '',
      itemNumber: item.itemNumber || item.item_number || item.ITEM_NUMBER || '',
      structureName: item.structureName || item.structure_name || item.STRUCTURE_NAME || 'PRIMARY',
      description: item.description || item.bom_description || item.DESCRIPTION || '',
      effectivityControl: item.effectivityControl || item.effectivity_control || item.EFFECTIVITY_CONTROL || '',
      sourceUpdatedAt: item.sourceUpdatedAt || item.source_updated_at || item.SOURCE_UPDATED_AT || '',
      importBatchId: item.importBatchId || item.import_batch_id || item.IMPORT_BATCH_ID || '',
      importedAt: item.importedAt || item.imported_at || item.IMPORTED_AT || '',
      healthScore: item.healthScore !== undefined ? item.healthScore : (item.health_score !== undefined ? item.health_score : 0),
      statusLabel: item.statusLabel || item.status_label || item.STATUS_LABEL || item.status || ''
    };
  };

  /**
   * Parses the components and matches findings to them
   */
  PageModule.prototype.parseComponentsResponse = function(responsePayload) {
    if (!responsePayload) return [];

    var dataToParse = responsePayload;
    if (responsePayload.items && responsePayload.items.length > 0 && responsePayload.items[0].bom_detail_json) {
      try {
        dataToParse = JSON.parse(responsePayload.items[0].bom_detail_json);
      } catch (e) {
        console.error("Failed to parse bom_detail_json in components:", e);
        return [];
      }
    }

    if (!dataToParse || !dataToParse.components) {
      return [];
    }
    
    var findings = dataToParse.findings || [];
    var components = dataToParse.components;
    
    return components.map(function(c) {
      var itemNum = c.componentItemNumber || c.component_item_number || '';
      
      // Match issues reliably using bomComponentId
      var hasIssue = findings.some(function(f) { 
        return f.bomComponentId === c.bomComponentId && (f.issueStatus || f.issue_status) !== 'IGNORED'; 
      });
      
      return {
        id: c.bomComponentId || c.bom_component_id || itemNum || Math.random().toString(),
        parentItemNumber: c.parentItemNumber || c.parent_item_number || '',
        level: c.bomLevel || c.bom_level || 1,
        itemNumber: itemNum,
        itemClass: c.componentItemClass || c.component_item_class || '',
        qty: c.quantity !== undefined ? c.quantity : 0,
        uom: c.uomCode || c.uom_code || '',
        status: c.itemStatus || c.item_status || 'Active',
        hasIssue: hasIssue,
        // NEW: Grab the path to build the tree reliably
        componentPath: c.componentPath || c.component_path || ''
      };
    });
  };

  /**
   * Parses the findings into the score deduction table format
   */
  PageModule.prototype.parseScoreDeductions = function(responsePayload) {
    if (!responsePayload) return [];
    
    var dataToParse = responsePayload;
    if (responsePayload.items && responsePayload.items.length > 0 && responsePayload.items[0].bom_detail_json) {
      try {
        dataToParse = JSON.parse(responsePayload.items[0].bom_detail_json);
      } catch (e) {
        return [];
      }
    }

    if (!dataToParse || !dataToParse.findings) {
      return [];
    }
    
    var findings = dataToParse.findings;
    return findings.map(function(f) {
      var deduction = 0;
      var sev = (f.severity || '').toUpperCase();
      var status = (f.issueStatus || f.issue_status || 'OPEN').toUpperCase();
      
      if (status !== 'IGNORED') {
        if (sev === 'CRITICAL') deduction = 20;
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

  PageModule.prototype.getTreeDataProvider = function(flatList) {
    if (!flatList || flatList.length === 0) {
      return new ArrayTreeDataProvider([], { keyAttributes: 'id' });
    }
    
    // 1. BULLETPROOF CACHE CHECK
    var currentFirstId = flatList.length > 0 ? flatList[0].id : null;
    if (this._cachedTreeProvider && 
        this._cachedListLength === flatList.length && 
        this._cachedFirstId === currentFirstId) {
      return this._cachedTreeProvider;
    }
    
    this._cachedListLength = flatList.length;
    this._cachedFirstId = currentFirstId;
    
    // 2. THE FIX: Create a deep clone to strip Visual Builder Proxy locks
    // This allows us to freely add the .children arrays without VB blocking it
    var plainList = JSON.parse(JSON.stringify(flatList));
    
    var pathMap = {};
    var roots = [];
    
    // 3. Map all items using their component paths
    plainList.forEach(function(item) {
      if (item.componentPath) {
        pathMap[item.componentPath] = item;
      }
    });
    
    // 4. Build the hierarchy
    plainList.forEach(function(item) {
      var isRoot = true;
      
      if (item.componentPath) {
        var pathParts = item.componentPath.split('/');
        
        // Length > 2 means it's a child of a subassembly (e.g., ASM/SUB/CMP)
        if (pathParts.length > 2) {
          pathParts.pop(); // Drop current item to get the parent path
          var parentPath = pathParts.join('/');
          
          // If parent is found, inject this item into its children array
          if (pathMap[parentPath]) {
            if (!pathMap[parentPath].children) {
              pathMap[parentPath].children = [];
            }
            pathMap[parentPath].children.push(item);
            isRoot = false; // It has a parent, so it's not a root row
          }
        }
      } else {
        if (item.level > 1) isRoot = false;
      }
      
      // If no parent was found, push it to the main top-level view
      if (isRoot) {
        roots.push(item);
      }
    });
    
    // 5. Initialize the Oracle JET tree provider with the un-proxied nested data
    this._cachedTreeProvider = new ArrayTreeDataProvider(roots, { 
      keyAttributes: 'id', 
      childrenAttribute: 'children' 
    });
    
    return this._cachedTreeProvider;
  };
  
  /**
   * Parses the findings into the score deduction table format
   * Matches the PL/SQL engine: CRITICAL (-25), HIGH (-10), WARNING (-5)
   */
  /**
   * Parses the findings into the score deduction table format
   * Matches the PL/SQL engine: CRITICAL (-25), HIGH (-10), WARNING (-5)
   */
  PageModule.prototype.parseScoreDeductions = function(responsePayload) {
    if (!responsePayload) return [];
    
    var dataToParse = responsePayload;
    if (responsePayload.items && responsePayload.items.length > 0 && responsePayload.items[0].bom_detail_json) {
      try {
        dataToParse = JSON.parse(responsePayload.items[0].bom_detail_json);
      } catch (e) {
        return [];
      }
    }

    if (!dataToParse || !dataToParse.findings || dataToParse.findings.length === 0) {
      return [];
    }
    
    var findings = dataToParse.findings;

    // 1. Find the most recent run ID to filter out historical duplicates
    var latestRunId = -1;
    findings.forEach(function(f) {
      if (f.runId && f.runId > latestRunId) {
        latestRunId = f.runId;
      }
    });

    // 2. Filter the list to ONLY include findings from the latest run
    var latestFindings = findings.filter(function(f) {
      return f.runId === latestRunId;
    });
    
    // 3. Map the filtered findings to table rows
    return latestFindings.map(function(f) {
      var deduction = 0;
      var sev = (f.severity || '').toUpperCase();
      var status = (f.issueStatus || f.issue_status || 'OPEN').toUpperCase();
      
      // Only OPEN or REVIEWED statuses deduct points
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
    }).filter(function(f) { 
      // Only return rows that actually deducted points for the UI table
      return f.deduction > 0; 
    });
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

  /**
   * Parses findings into the auditTrailList format for the History tab
   */
  PageModule.prototype.parseAuditTrail = function(responsePayload) {
    if (!responsePayload) return [];

    var dataToParse = responsePayload;
    if (responsePayload.items && responsePayload.items.length > 0 && responsePayload.items[0].bom_detail_json) {
      try {
        dataToParse = JSON.parse(responsePayload.items[0].bom_detail_json);
      } catch (e) {
        return [];
      }
    }

    if (!dataToParse || !dataToParse.findings) {
      return [];
    }

    return dataToParse.findings.map(function(f) {
      return {
        findingId: f.findingId || f.finding_id || '',
        rule: f.ruleName || f.rule_name || f.ruleCode || f.rule_code || 'Validation Rule',
        timestamp: f.createdAt ? new Date(f.createdAt).toLocaleString() : 'Recent',
        oldStatus: 'OPEN',
        newStatus: f.issueStatus || f.issue_status || 'OPEN',
        user: f.reviewedBy || f.reviewed_by || 'System',
        
        // STRICTLY NO ACTUAL VALUE HERE! ONLY THE REAL COMMENT!
        comment: f.reviewComment || f.review_comment || '' 
      };
    });
  };

  // Checks if the findings API response returned zero items
  PageModule.prototype.checkIfEmpty = function(response) {
    if (!response) return true;
    var body = response.body || response;
    var items = body.items || body;
    return !Array.isArray(items) || items.length === 0;
  };
  /**
   * Fetches the most recent advisory from getBomsBomIdAdvisories
   * and extracts ai_summary and ai_suggested_action
   */
  PageModule.prototype.parseLatestBomAdvisory = function(responsePayload) {
    var result = {
      status: 'NOT_REQUESTED',
      context: 'No global AI Advisory has been generated for this BOM yet.',
      mitigation: ''
    };

    if (!responsePayload) return result;

    var items = responsePayload.items || (Array.isArray(responsePayload) ? responsePayload : []);
    if (items.length === 0) return result;

    // Top item is the most recent advisory because SQL uses ORDER BY generated_at DESC
    var latest = items[0];
    result.status = latest.ai_status || latest.aiStatus || 'COMPLETED';

    var summary = latest.ai_summary || latest.aiSummary || '';
    var suggested = latest.ai_suggested_action || latest.aiSuggestedAction || '';

    // Safely unwrap nested OIC stringified JSON if present
    if (typeof summary === 'string' && summary.trim().startsWith('{')) {
      try {
        var parsed = JSON.parse(summary);
        summary = parsed.ai_summary || summary;
        suggested = parsed.ai_suggested_action || suggested;
      } catch (e) {
        console.log("Advisory summary is standard text.");
      }
    }

    result.context = summary;
    result.mitigation = suggested;

    return result;
  };
  /**
   * Parses the direct response from the OIC Advisory Service.
   */
  /**
   * Parses the direct response from the OIC Advisory Service.
   */
  PageModule.prototype.parseOICResponse = function(responsePayload) {
    var result = { status: 'COMPLETED', context: '', mitigation: '' };
    
    if (!responsePayload) {
        result.status = 'ERROR';
        result.context = 'Received empty response from OIC.';
        return result;
    }

    // Safely grab the raw values from OIC
    var summaryRaw = responsePayload.ai_summary || responsePayload.aiSummary || '';
    var suggestedRaw = responsePayload.ai_suggested_action || responsePayload.aiSuggestedAction || '';

    // Handle VB wrapper quirks (sometimes it puts the body inside items[0])
    if (responsePayload.items && responsePayload.items.length > 0) {
        summaryRaw = responsePayload.items[0].ai_summary || summaryRaw;
        suggestedRaw = responsePayload.items[0].ai_suggested_action || suggestedRaw;
    }

    try {
      // If OIC stringified the JSON, safely parse it
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
    
    // Fallback if parsing resulted in empty text
    if (!result.context || result.context.trim() === '') {
         result.context = "Advisory generated but returned no text. Check OIC logs.";
    }

    return result;
  };
  return PageModule;
});