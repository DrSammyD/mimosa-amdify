"use strict";
var path;

path = require('path');

exports.defaults = function() {
  return {
    amdify: {
      path: './assets/javascripts/app/',
      envVars: ['browser', 'ecmaIdentifiers', 'reservedVars'],
      excludePaths: ['../vendor/requirejs/require.js'],
      includePaths: ['../vendor'],
      amdifyDir: {
        path: ".mimosa/amdify",
        clean: true
      }
    }
  };
};

exports.placeholder = function() {
  return " \t\n\n   amdify:          # Configuration for the mimosa-require-admify module\n     path: './assets/javascripts/app/'\n     envVars: ['browser','ecmaIdentifiers','reservedVars']\n     globals: {'jquery':['jQuery','$']}\n     excludePaths:['../vendor/requirejs/require.js']\n     includePaths: ['../vendor']\n     shim:\n       '../vendor/modernizr/modernizr.js':\n         export: ['Modernizr']";
};

exports.validate = function(config, validators) {
  var errors, javascriptDir;
  errors = [];
  if (validators.ifExistsIsObject(errors, "amdify config", config.amdify)) {
    javascriptDir = path.join(config.watch.sourceDir, config.watch.javascriptDir);
    validators.ifExistsFileExcludeWithRegexAndString(errors, "amdify.exclude", config.amdify, javascriptDir);
  }
  return errors;
};
