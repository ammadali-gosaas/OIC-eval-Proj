define(['knockout', 'ojs/ojarraydataprovider', 'ojs/ojpagingdataproviderview'], function(ko, ArrayDataProvider, PagingDataProviderView) {
  'use strict';

  function PageModule() {
    this.masterList = [];
    this.currentFilter = null;

    // Single persistent Knockout observable array for reactive updates
    this.bomsObservable = ko.observableArray([]);

    // Permanent DataProvider instances created ONCE on page load
    const adp = new ArrayDataProvider(this.bomsObservable, { keyAttributes: 'bom_id' });
    this.pagingADP = new PagingDataProviderView(adp);
  }

  /**
   * Helper to force oj-table to discard stale fetch iterators and redraw Page 1
   */
  PageModule.prototype.refreshTable = function() {
    setTimeout(function() {
      const table = document.getElementById('bomsTable');
      if (table && typeof table.refresh === 'function') {
        table.refresh();
      }
    }, 0);
  };

  /**
   * Returns single stable PagingDataProviderView reference
   */
  PageModule.prototype.getBomsADP = function() {
    return this.pagingADP;
  };

  PageModule.prototype.getPagingData = function() {
    return this.pagingADP;
  };

  /**
   * Called by Action Chain when ORDS GET /boms finishes.
   * Mutates observable array -> JET Table & Pagination update instantly!
   */
  PageModule.prototype.setBomsData = function(responsePayload) {
    let items = [];
    if (Array.isArray(responsePayload)) {
      items = responsePayload;
    } else if (responsePayload && Array.isArray(responsePayload.items)) {
      items = responsePayload.items;
    }

    this.masterList = items;
    this.currentFilter = null;
    this.bomsObservable(items);
    this.refreshTable();
    return items;
  };

  /**
   * Dynamically filters live ORDS records by finding severity
   */
  PageModule.prototype.filterBySeverity = function(severity) {
    if (this.currentFilter === severity) {
      return this.clearSeverityFilter();
    }

    this.currentFilter = severity;
    const target = (severity || '').toUpperCase();

    const filtered = this.masterList.filter(function(item) {
      const severities = item.finding_severities || item.findingSeverities || item.FINDING_SEVERITIES || '';
      if (severities) {
        return severities.toUpperCase().indexOf(target) !== -1;
      }

      if (Array.isArray(item.findings) && item.findings.length > 0) {
        return item.findings.some(function(f) {
          const isSevMatch = (f.severity || f.rule_severity || '').toUpperCase() === target;
          const isActive = !f.issue_status || f.issue_status === 'OPEN' || f.issue_status === 'REVIEWED';
          return isSevMatch && isActive;
        });
      }

      return false;
    });

    this.bomsObservable(filtered);
    this.refreshTable();
    return this.currentFilter || "";
  };

  /**
   * Clears filter and restores full ORDS dataset
   */
  PageModule.prototype.clearSeverityFilter = function() {
    this.currentFilter = null;
    this.bomsObservable(this.masterList);
    this.refreshTable();
    return "";
  };

  /**
   * Parses live payload from ORDS Dashboard API dynamically
   */
  PageModule.prototype.parseDashboardResponse = function(responsePayload) {
    let summary = { totalBoms: 0, healthyBoms: 0, riskyBoms: 0, openFindings: 0 };
    let critical = 0, high = 0, warning = 0, info = 0;
    let itemClasses = [];

    if (responsePayload && responsePayload.items && responsePayload.items[0]) {
      try {
        const rawJson = responsePayload.items[0].dashboard_json;
        const parsed = typeof rawJson === 'string' ? JSON.parse(rawJson) : rawJson;
        
        if (parsed && parsed.summary) summary = parsed.summary;
        if (parsed && parsed.severityCounts && Array.isArray(parsed.severityCounts)) {
          parsed.severityCounts.forEach(function(s) {
            if (s.severity === 'CRITICAL') critical = s.findingCount;
            if (s.severity === 'HIGH') high = s.findingCount;
            if (s.severity === 'WARNING') warning = s.findingCount;
            if (s.severity === 'INFO') info = s.findingCount;
          });
        }
        if (parsed && parsed.itemClassSummary && Array.isArray(parsed.itemClassSummary)) {
          const nameMap = {
            'ELECTRONICS': 'Electronic Components',
            'MECHANICAL': 'Mechanical Parts',
            'HYDRAULIC': 'Hydraulic Systems',
            'FASTENERS': 'Screws & Fasteners'
          };

          itemClasses = parsed.itemClassSummary.map(function(cls) {
            const displayName = nameMap[cls.itemClass] || cls.itemClass;
            const avgHealth = Math.round(cls.averageHealthScore || 0);
            const total = cls.bomCount || 0;
            const risky = cls.riskyCount !== undefined ? cls.riskyCount : (avgHealth < 100 ? total : 0);
            
            const barColor = avgHealth >= 90 ? '#10b981' : (avgHealth >= 70 ? '#f59e0b' : '#f43f5e');
            const textColor = avgHealth >= 90 ? '#047857' : (avgHealth >= 70 ? '#b45309' : '#be123c');
            const riskLabel = avgHealth + '% Health';

            return {
              name: displayName,
              total: total,
              risky: risky,
              healthPct: avgHealth,
              barColor: barColor,
              textColor: textColor,
              riskLabel: riskLabel
            };
          });
        }
      } catch (e) {
        console.error('Error parsing ORDS JSON string:', e);
      }
    }

    return {
      totalBoms: summary.totalBoms || 0,
      healthyBoms: summary.healthyBoms || 0,
      riskyBoms: summary.riskyBoms || 0,
      openFindings: summary.openFindings || 0,
      critical: critical,
      high: high,
      warning: warning,
      info: info,
      itemClasses: itemClasses,
      itemClass1: itemClasses[0] || { name: 'Electronic Components', total: 0, risky: 0, healthPct: 0, barColor: '#10b981', textColor: '#047857', riskLabel: '0% Health' },
      itemClass2: itemClasses[1] || { name: 'Mechanical Parts', total: 0, risky: 0, healthPct: 0, barColor: '#10b981', textColor: '#047857', riskLabel: '0% Health' },
      itemClass3: itemClasses[2] || { name: 'Hydraulic Systems', total: 0, risky: 0, healthPct: 0, barColor: '#10b981', textColor: '#047857', riskLabel: '0% Health' }
    };
  };

  /**
   * Dynamically filters live ORDS records by Item Class
   */
  PageModule.prototype.filterByItemClass = function(itemClass) {
    if (this.currentFilter === itemClass) {
      return this.clearSeverityFilter();
    }
    this.currentFilter = itemClass;
    const target = (itemClass || '').toUpperCase();

    const filtered = this.masterList.filter(function(item) {
      const itemCls = (item.item_class || item.itemClass || '').toUpperCase();
      if (target.indexOf('ELECTRONIC') !== -1) return itemCls === 'ELECTRONICS' || itemCls.indexOf('ELECTRONIC') !== -1;
      if (target.indexOf('HYDRAULIC') !== -1) return itemCls === 'HYDRAULIC';
      if (target.indexOf('MECHANICAL') !== -1) return itemCls === 'MECHANICAL';
      if (target.indexOf('FASTENER') !== -1) return itemCls === 'FASTENERS' || itemCls.indexOf('FASTENER') !== -1;
      if (target.indexOf('PACKAGING') !== -1) return itemCls === 'PACKAGING' || itemCls.indexOf('PACKAGING') !== -1;
      return itemCls === target;
    });

    this.bomsObservable(filtered);
    this.refreshTable();
    return this.currentFilter || "";
  };

  return PageModule;
});