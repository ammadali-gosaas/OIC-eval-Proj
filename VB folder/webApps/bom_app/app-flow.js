define([], () => {
  'use strict';

  // Single source of truth for role capabilities. Add new roles/actions here only.
  const ROLE_PERMISSIONS = {
    'Administrator': { run: true, logs: true, review: true, ai: true, manageRules: true },
    'Business Reviewer': { run: false, logs: false, review: true, ai: true, manageRules: false }
  };

  const ROLE_NOTES = {
    'Administrator': 'Import/run validation, view logs, view BOM results, review findings, request explanations.',
    'Business Reviewer': 'View BOM results, review findings, change status, request Advisory AI explanations.'
  };

  class AppModule {
    /**
     * Returns true if the given role is allowed to perform the given action.
     * action is one of: 'run', 'logs', 'review', 'ai', 'manageRules'
     */
    hasPermission(role, action) {
      const perms = ROLE_PERMISSIONS[role];
      return !!(perms && perms[action]);
    }

    /**
     * Short description of what the given role can do, for display in the UI.
     */
    getRoleNote(role) {
      return ROLE_NOTES[role] || '';
    }
  }
  
  return AppModule;
});
