"use strict";
var config, defineRegex, envVars, globalsRegex, jsh, logger, path, registration, _, _applyCommonJSWrapper, _wrap,
  __slice = [].slice;

config = require('./config');

jsh = require('jshint');

_ = require('lodash');

path = require('path');

defineRegex = /(?:(?!\.))define\(/;

globalsRegex = ['window(\.|\[[\"\'])', '([\"\']\])?\s*?='];

logger = null;

envVars = _(require.cache).pairs().filter(function(item) {
  return item[0].indexOf('vars.js') !== -1 && item[1].parent.id.indexOf('jshint.js') !== -1;
}).map(function(item) {
  return item[1].exports;
}).first();

registration = function(mimosaConfig, register) {
  var amdify;
  logger = mimosaConfig.log;
  amdify = mimosaConfig.amdify;
  envVars = _(envVars).pairs().filter(function(vars) {
    return amdify.envVars.cointains(vars[0]);
  }).map(function(vars) {
    return vars[1];
  }).flatten().value();
  amdify.globals = _(amdify.globals).map(function(val, key) {
    return _(val).map(function(item) {
      return [item, key];
    }).value();
  }).flatten(true).object().value();
  return register(['add', 'update', 'buildFile'], 'afterCompile', _applyCommonJSWrapper, __slice.call(mimosaConfig.extensions.javascript));
};

_applyCommonJSWrapper = function(mimosaConfig, options, next) {
  var amdify, file, hasFiles, shims, waiting, _ref;
  hasFiles = ((_ref = options.files) != null ? _ref.length : void 0) > 0;
  if (!hasFiles) {
    return next();
  }
  amdify = mimosaConfig.amdify;
  shims = _(amdify.shim).pairs();
  waiting = {};
  _(options.files).each(function(file) {
    var relName;
    if (file.outputFileText.match(defineRegex)) {
      if (logger.isDebug()) {
        return logger.debug("Not wrapping [[ " + file.inputFileName + " ]], it already contains a define block");
      } else {
        relName = path.relative(amdify.path, file.inputFileName);
        jsh.JSHINT(file.outputFileText);
        _(jsh.JSHINT.data().implieds).pluck('name').each(function(implied) {
          var glreg;
          glreg = new RegExp(globalsRegex[0] + implied + globalsRegex[1], 'g');
          if (file.outputFileText.match(glreg)) {
            return file.outputFileText = "var " + implied + "; " + (file.outputFileText.replace(glreg, implied + '='));
          }
        });
        jsh.JSHINT(file.outputFileText);
        file.shim = shims.filter(function(pair) {
          return pair[0] === relName;
        }).map(function(pair) {
          return pair[1];
        }).first() || {};
        file.deps = _(jsh.JSHINT.data().implieds).pluck('name').value();
        file.exports = file.shim["export"] ? [file.shim["export"]] : _(jsh.JSHINT.data().globals).difference(envVars).filter(function(item) {
          return item !== 'undefined';
        }).value();
        return waiting[file.shim.name || relName] = file;
      }
    }
  });
  for (file in waiting) {
    file.shim.deps = _(file.shim.deps || []).map(function(dep) {
      if (waiting[dep]) {
        return [dep, waiting[dep]];
      }
    }).filter().value();
    file.deps = _(file.deps).map(function(dep) {
      return [dep, amdify.globals[dep]];
    }).filter().value();
    file.outputFileText = _wrap(file, mimosaConfig.amdify);
  }
  return next();
};

_wrap = function(file, amdify) {
  var exports, funcStart, imports, start;
  start = "define( " + (_(file.deps).map(function(item) {
    return item[1];
  }).join(',')) + "," + (_(file.shim.deps).map(function(item) {
    return item[0];
  }));
  funcStart = ",function( " + (_(file.deps).map(function(item) {
    return item[0];
  }).join(',')) + ", " + (_(file.shim.deps).map(function(val, index) {
    return '__amdify__' + index;
  }).join(',')) + " ){";
  imports = _(file.shim.deps).map(function(val, index) {
    return _(val[1].exports).map(function(exp) {
      if (exp.length > 1) {
        return _(exp).intersect(file.deps).map(function(common) {
          return "var " + common + " = __amdify__" + index + "." + common + ";";
        });
      } else if (exp.length === 1) {
        return _(exp).intersect(file.deps).map(function(common) {
          return "var " + common + " = __amdify__" + index;
        });
      }
    }).flatten().value();
  }).flatten().join('\n');
  if (file.exports.length > 1) {
    exports = "return { " + (_(file.exports).map(function(exp) {
      return exp + ':' + exp;
    }).join(',')) + " };";
  } else if (file.exports.length === 1) {
    exports = "return " + (_.first(file.exports));
  }
  return "" + start + funcStart + "\n" + imports + "\n" + file.outputFileText + "\n" + exports + "\n});";
};

module.exports = {
  registration: registration,
  defaults: config.defaults,
  placeholder: config.placeholder,
  validate: config.validate
};
