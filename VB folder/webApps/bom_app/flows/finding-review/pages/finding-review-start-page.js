{
  "title": "Finding Review",
  "description": "Global finding review workflow — live data from BOMValidation API",
  "variables": {
    "selectedFindingId": {
      "type": "string"
    },
    "newStatus": {
      "type": "string",
      "defaultValue": "OPEN"
    },
    "statusComment": {
      "type": "string",
      "defaultValue": ""
    },
    "advisoryStatus": {
      "type": "string",
      "defaultValue": "NOT_REQUESTED"
    },
    "advisoryText": {
      "type": "string",
      "defaultValue": ""
    },
    "advisoryMitigation": {
      "type": "string",
      "defaultValue": ""
    },
    "advisoryRequestId": {
      "type": "string",
      "defaultValue": ""
    },
    "isSavingStatus": {
      "type": "boolean",
      "defaultValue": false
    },
    "filterStatus": {
      "type": "string",
      "defaultValue": ""
    },
    "filterSeverity": {
      "type": "string",
      "defaultValue": ""
    },
    "findingsSdp": {
      "type": "vb/ServiceDataProvider",
      "defaultValue": {
        "endpoint": "BOMValidation/listFindings",
        "keyAttributes": "finding_id",
        "itemsPath": "items"
      }
    }
  },
  "metadata": {},
  "types": {},
  "chains": {
    "LoadStylesChain": {
      "root": "callFunctionLoadTailwind",
      "actions": {
        "callFunctionLoadTailwind": {
          "module": "vb/action/builtin/callModuleFunctionAction",
          "parameters": {
            "module": "[[ $functions ]]",
            "functionName": "loadTailwind"
          }
        }
      }
    },
    "SelectFindingChain": {
      "variables": {
        "findingId": {
          "type": "string",
          "input": "fromCaller"
        }
      },
      "root": "assignFindingId",
      "actions": {
        "assignFindingId": {
          "module": "vb/action/builtin/assignVariablesAction",
          "parameters": {
            "$page.variables.selectedFindingId": {
              "source": "{{ $chain.variables.findingId }}"
            },
            "$page.variables.advisoryStatus": {
              "source": "NOT_REQUESTED"
            },
            "$page.variables.advisoryText": {
              "source": ""
            },
            "$page.variables.advisoryMitigation": {
              "source": ""
            }
          }
        }
      }
    },
    "UpdateStatusChain": {
      "description": "PATCH BOMValidation/updateFindingStatus with new status and optional comment",
      "root": "setSaving",
      "actions": {
        "setSaving": {
          "module": "vb/action/builtin/assignVariablesAction",
          "parameters": {
            "$page.variables.isSavingStatus": {
              "source": true
            }
          },
          "outcomes": {
            "success": "callUpdateStatus"
          }
        },
        "callUpdateStatus": {
          "module": "vb/action/builtin/restAction",
          "parameters": {
            "endpoint": "BOMValidation/updateFindingStatus",
            "uriParams": {
              "finding_id": "{{ $page.variables.selectedFindingId }}"
            },
            "body": {
              "status": "{{ $page.variables.newStatus }}",
              "comment": "{{ $page.variables.statusComment }}"
            }
          },
          "outcomes": {
            "success": "notifySuccess",
            "failure": "notifyError"
          }
        },
        "notifySuccess": {
          "module": "vb/action/builtin/fireNotificationEventAction",
          "parameters": {
            "target": "leaf",
            "summary": "Finding status updated successfully.",
            "type": "confirmation",
            "displayMode": "transient"
          },
          "outcomes": {
            "success": "clearSaving"
          }
        },
        "notifyError": {
          "module": "vb/action/builtin/fireNotificationEventAction",
          "parameters": {
            "target": "leaf",
            "summary": "Failed to update status. Please try again.",
            "type": "error",
            "displayMode": "persist"
          },
          "outcomes": {
            "success": "clearSaving"
          }
        },
        "clearSaving": {
          "module": "vb/action/builtin/assignVariablesAction",
          "parameters": {
            "$page.variables.isSavingStatus": {
              "source": false
            }
          }
        }
      }
    },
    "RequestAdvisoryChain": {
      "description": "POST createFindingAdvisory then GET getAdvisory for the selected finding",
      "root": "setAdvisoryLoading",
      "actions": {
        "setAdvisoryLoading": {
          "module": "vb/action/builtin/assignVariablesAction",
          "parameters": {
            "$page.variables.advisoryStatus": {
              "source": "GENERATING"
            },
            "$page.variables.advisoryText": {
              "source": "Generating AI advisory…"
            },
            "$page.variables.advisoryMitigation": {
              "source": ""
            }
          },
          "outcomes": {
            "success": "callCreateAdvisory"
          }
        },
        "callCreateAdvisory": {
          "module": "vb/action/builtin/restAction",
          "parameters": {
            "endpoint": "BOMValidation/createFindingAdvisory",
            "uriParams": {
              "finding_id": "{{ $page.variables.selectedFindingId }}"
            }
          },
          "outcomes": {
            "success": "extractRequestId",
            "failure": "advisoryError"
          }
        },
        "extractRequestId": {
          "module": "vb/action/builtin/callModuleFunctionAction",
          "parameters": {
            "module": "[[ $functions ]]",
            "functionName": "extractAdvisoryRequestId",
            "params": [
              "{{ $chain.results.callCreateAdvisory.body }}"
            ]
          },
          "outcomes": {
            "success": "saveRequestId"
          }
        },
        "saveRequestId": {
          "module": "vb/action/builtin/assignVariablesAction",
          "parameters": {
            "$page.variables.advisoryRequestId": {
              "source": "{{ $chain.results.extractRequestId }}",
              "auto": "always"
            }
          },
          "outcomes": {
            "success": "pollAdvisory"
          }
        },
        "pollAdvisory": {
          "module": "vb/action/builtin/restAction",
          "parameters": {
            "endpoint": "BOMValidation/getAdvisory",
            "uriParams": {
              "requestId": "{{ $page.variables.advisoryRequestId }}"
            }
          },
          "outcomes": {
            "success": "parseAdvisory",
            "failure": "advisoryError"
          }
        },
        "parseAdvisory": {
          "module": "vb/action/builtin/callModuleFunctionAction",
          "parameters": {
            "module": "[[ $functions ]]",
            "functionName": "parseAdvisoryResponse",
            "params": [
              "{{ $chain.results.pollAdvisory.body }}"
            ]
          },
          "outcomes": {
            "success": "assignAdvisory"
          }
        },
        "assignAdvisory": {
          "module": "vb/action/builtin/assignVariablesAction",
          "parameters": {
            "$page.variables.advisoryStatus": {
              "source": "{{ $chain.results.parseAdvisory.status }}",
              "auto": "always"
            },
            "$page.variables.advisoryText": {
              "source": "{{ $chain.results.parseAdvisory.context }}",
              "auto": "always"
            },
            "$page.variables.advisoryMitigation": {
              "source": "{{ $chain.results.parseAdvisory.mitigation }}",
              "auto": "always"
            }
          }
        },
        "advisoryError": {
          "module": "vb/action/builtin/assignVariablesAction",
          "parameters": {
            "$page.variables.advisoryStatus": {
              "source": "ERROR"
            },
            "$page.variables.advisoryText": {
              "source": "Advisory generation failed. Please try again."
            }
          }
        }
      }
    }
  },
  "eventListeners": {
    "vbEnter": {
      "chains": [
        {
          "chainId": "LoadStylesChain"
        }
      ]
    },
    "clickFinding": {
      "chains": [
        {
          "chainId": "SelectFindingChain",
          "parameters": {
            "findingId": "{{ $event.currentTarget.dataset.findingId }}"
          }
        }
      ]
    },
    "clickSaveStatus": {
      "chains": [
        {
          "chainId": "UpdateStatusChain"
        }
      ]
    },
    "clickRequestAdvisory": {
      "chains": [
        {
          "chainId": "RequestAdvisoryChain"
        }
      ]
    }
  },
  "imports": {
    "components": {
      "oj-bind-text": {
        "path": "ojs/ojbindtext"
      },
      "oj-bind-for-each": {
        "path": "ojs/ojbindforeach"
      },
      "oj-bind-if": {
        "path": "ojs/ojbindif"
      }
    }
  }
}