define([], function () {
  'use strict';

  var PageModule = function PageModule() { };

  PageModule.prototype.loadTailwind = function () {
    if (!document.getElementById('tailwind-cdn')) {
      var script = document.createElement('script');
      script.id = 'tailwind-cdn';
      script.src = 'https://cdn.tailwindcss.com';
      document.head.appendChild(script);
    }
  };

  PageModule.prototype.formatConfigString = function(config) {
    if (!config) return '';
    if (typeof config === 'object') {
      try { return JSON.stringify(config); } catch(e) { return ''; }
    }
    return String(config);
  };

  PageModule.prototype.parseRuleConfig = function(ruleCode, configInput) {
    let config = {};
    if (typeof configInput === 'object' && configInput !== null) {
      config = configInput;
    } else if (typeof configInput === 'string' && configInput.trim() !== '') {
      try { config = JSON.parse(configInput); } catch(e) { config = {}; }
    }
    
    let state = {
      allowWs: false,
      defUom: true,
      op: '>',
      target: 0,
      allowNull: false,
      opSeq: false,
      statuses: '',
      endAfter: true,
      open: true,
      depth: 50,
      useComp: true,
      min: 0.1,
      max: 1000
    };

    if (ruleCode === 'FR-008') {
      state.allowWs = !!config.allow_whitespace;
      state.defUom = config.default_uom_allowed !== false;
    } else if (ruleCode === 'FR-009') {
      state.op = config.operator || '>';
      state.target = config.target_value !== undefined ? config.target_value : 0;
      state.allowNull = !!config.allow_null;
    } else if (ruleCode === 'FR-010') {
      state.opSeq = Array.isArray(config.match_fields) && config.match_fields.includes("operation_sequence");
    } else if (ruleCode === 'FR-011') {
      state.statuses = Array.isArray(config.invalid_statuses) ? config.invalid_statuses.join(', ') : '';
    } else if (ruleCode === 'FR-012') {
      state.endAfter = config.validate_end_after_start !== false;
      state.open = config.allow_open_ended !== false;
    } else if (ruleCode === 'FR-013') {
      state.depth = config.max_traversal_depth || 50;
    } else if (ruleCode === 'FR-014') {
      state.useComp = config.use_component_thresholds !== false;
      state.min = config.fallback_min !== undefined ? config.fallback_min : 0.1;
      state.max = config.fallback_max !== undefined ? config.fallback_max : 1000;
    }
    return state;
  };

  PageModule.prototype.buildRuleConfig = function(ruleCode, state) {
    state = state || {};
    let config = {};

    if (ruleCode === 'FR-008') {
      config.allow_whitespace = !!state.allowWs;
      config.default_uom_allowed = !!state.defUom;
    } else if (ruleCode === 'FR-009') {
      config.operator = state.op || '>';
      config.target_value = Number(state.target);
      config.allow_null = !!state.allowNull;
    } else if (ruleCode === 'FR-010') {
      let fields = ["parent_item_number", "component_item_number", "effectivity_start"];
      if (state.opSeq) fields.push("operation_sequence");
      config.match_fields = fields;
    } else if (ruleCode === 'FR-011') {
      config.invalid_statuses = typeof state.statuses === 'string' 
        ? state.statuses.split(',').map(s => s.trim()).filter(s => s) 
        : [];
    } else if (ruleCode === 'FR-012') {
      config.validate_end_after_start = !!state.endAfter;
      config.allow_open_ended = !!state.open;
    } else if (ruleCode === 'FR-013') {
      config.max_traversal_depth = Number(state.depth);
    } else if (ruleCode === 'FR-014') {
      config.use_component_thresholds = !!state.useComp;
      config.fallback_min = Number(state.min);
      config.fallback_max = Number(state.max);
    }
    return JSON.stringify(config);
  };

  // Dynamically updates config parameters state object on key/click events
  PageModule.prototype.updateConfigState = function(currentState, key, val, isCheckbox) {
    let newState = Object.assign({}, currentState || {});
    if (isCheckbox === true || isCheckbox === 'true' || isCheckbox === 'checkbox') {
      newState[key] = !!val;
    } else {
      newState[key] = val;
    }
    return newState;
  };

  PageModule.prototype.formatScheduleInfo = function (item) {
    if (!item) return 'No active background schedule configured.';

    let intervalStr = (item.repeat_interval || '').toUpperCase();
    let frequency = intervalStr.includes('FREQ=WEEKLY') ? 'Weekly' : 'Daily';

    let nextRunDate = item.next_run_date ? new Date(item.next_run_date) : null;
    let timeFormatted = '';
    let dateFormatted = '';

    if (nextRunDate && !isNaN(nextRunDate.getTime())) {
      timeFormatted = nextRunDate.toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
      });
      dateFormatted = nextRunDate.toLocaleDateString([], {
        month: 'short',
        day: 'numeric',
        year: 'numeric'
      });
    }

    return frequency + ' at ' + timeFormatted + ' (GMT+5) • Next Run: ' + dateFormatted + ' at ' + timeFormatted;
  };

  return PageModule;
});