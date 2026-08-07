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

  // Parses the raw JSON string from the DB into a flat state object for the UI
  PageModule.prototype.parseRuleConfig = function(ruleCode, configStr) {
    let config = {};
    try { config = JSON.parse(configStr || '{}'); } catch(e){}
    
    let state = {};
    if (ruleCode === 'FR-008') {
      state.allowWs = !!config.allow_whitespace;
      state.defUom = config.default_uom_allowed !== false;
    } else if (ruleCode === 'FR-009') {
      state.op = config.operator || '>';
      state.target = config.target_value || 0;
      state.allowNull = !!config.allow_null;
    } else if (ruleCode === 'FR-010') {
      state.opSeq = config.match_fields && config.match_fields.includes("operation_sequence");
    } else if (ruleCode === 'FR-011') {
      state.statuses = (config.invalid_statuses || []).join(', ');
    } else if (ruleCode === 'FR-012') {
      state.endAfter = config.validate_end_after_start !== false;
      state.open = config.allow_open_ended !== false;
    } else if (ruleCode === 'FR-013') {
      state.depth = config.max_traversal_depth || 50;
    } else if (ruleCode === 'FR-014') {
      state.useComp = config.use_component_thresholds !== false;
      state.min = config.fallback_min || 0.1;
      state.max = config.fallback_max || 1000;
    }
    return state;
  };

  // Converts the UI state object back into the specific JSON format the DB requires
  PageModule.prototype.buildRuleConfig = function(ruleCode, state) {
    let config = {};
    if (ruleCode === 'FR-008') {
      config.allow_whitespace = !!state.allowWs;
      config.default_uom_allowed = !!state.defUom;
    } else if (ruleCode === 'FR-009') {
      config.operator = state.op;
      config.target_value = Number(state.target);
      config.allow_null = !!state.allowNull;
    } else if (ruleCode === 'FR-010') {
      let fields = ["parent_item_number", "component_item_number", "effectivity_start"];
      if (state.opSeq) fields.push("operation_sequence");
      config.match_fields = fields;
    } else if (ruleCode === 'FR-011') {
      config.invalid_statuses = (state.statuses || '').split(',').map(s => s.trim()).filter(s => s);
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

  return PageModule;
});