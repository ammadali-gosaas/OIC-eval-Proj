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

  return PageModule;
});