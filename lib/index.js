"use strict";
var amdify, clean, config, defineRegex, envVars, globalsRegex, jsh, jshintResults, logger, path, registration, shims, track, _, _analizeFiles, _applyRequireJSWrapper, _setJshintResult, _wrap,
  __slice = [].slice;

config = require('./config');

track = require('./track');

clean = require('./clean');

jsh = require('jshint');

_ = require('lodash');

path = require('path');

defineRegex = /(?:^\s*|[}{\(\);,\n\?\&]\s*)define\s*\(\s*("[^"]+"\s*,\s*|'[^']+'\s*,\s*)?\s*(\[(\s*(("[^"]+"|'[^']+')\s*,|\/\/.*\r?\n|\/\*(.|\s)*?\*\/))*(\s*("[^"]+"|'[^']+')\s*,?\s*)?(\s*(\/\/.*\r?\n|\/\*(.|\s)*?\*\/)\s*)*\]|function\s*|{|[_$a-zA-Z\xA0-\uFFFF][_$a-zA-Z0-9\xA0-\uFFFF]*\))/g;

globalsRegex = ['window(\.|\[[\"\'])', '([\"\']\])?\s*?='];

logger = null;

envVars = _(require.cache).pairs().filter(function(item) {
  return item[0].indexOf('vars.js') !== -1 && item[1].parent.id.indexOf('jshint.js') !== -1;
}).map(function(item) {
  return item[1].exports;
}).first();

jshintResults = {};

shims = null;

amdify = null;

registration = function(mimosaConfig, register) {
  logger = mimosaConfig.log;
  amdify = mimosaConfig.amdify;
  envVars = _(envVars).pairs().filter(function(vars) {
    return _(amdify.envVars).contains(vars[0]);
  }).map(function(vars) {
    return vars[1];
  }).flatten().value();
  amdify.globals = _(amdify.globals).map(function(val, key) {
    return _(val).map(function(item) {
      return [item, key];
    }).value();
  }).flatten(true).object().value();
  shims = _(amdify.shim).pairs();
  jshintResults = track.getPreviousAnalyzedFileList(mimosaConfig);
  register(['add', 'update', 'buildFile'], 'beforeCompile', _analizeFiles, __slice.call(mimosaConfig.extensions.javascript));
  return register(['add', 'update', 'buildFile'], 'beforeWrite', _applyRequireJSWrapper, __slice.call(mimosaConfig.extensions.javascript));
};

_setJshintResult = function(file, shim, relName) {
  jsh.JSHINT(file.inputFileText);
  _(jsh.JSHINT.data().implieds).pluck('name').each(function(implied) {
    var glreg;
    glreg = new RegExp(globalsRegex[0] + implied + globalsRegex[1], 'g');
    if (file.inputFileText.match(glreg)) {
      return file.inputFileText = "var " + implied + "; " + (file.inputFileText.replace(glreg, implied + '='));
    }
  });
  jsh.JSHINT(file.inputFileText);
  file = {
    shim: shim
  };
  file.deps = _(jsh.JSHINT.data().implieds).pluck('name').value();
  file.exports = file.shim["export"] ? [file.shim["export"]] : _(jsh.JSHINT.data().globals).difference(envVars).filter(function(item) {
    return item !== 'undefined';
  }).value();
  return jshintResults[file.shim.name || relName] = file;
};

_analizeFiles = function(mimosaConfig, options, next) {
  var hasFiles, _ref;
  hasFiles = ((_ref = options.files) != null ? _ref.length : void 0) > 0;
  if (!hasFiles) {
    return next();
  }
  _(options.files).each(function(file) {
    var relName, shim;
    if (file.inputFileText.match(defineRegex)) {
      if (logger.isDebug()) {
        return logger.debug("Not wrapping [[ " + file.inputFileName + " ]], it already contains a define block");
      }
    } else {
      relName = path.relative(amdify.path, file.inputFileName);
      return shim = shims.filter(function(pair) {
        return pair[0] === relName;
      }).map(function(pair) {
        return pair[1];
      }).first() || {};
    }
  });
  track.track(mimosaConfig, jshintResults);
  return next();
};

_applyRequireJSWrapper = function(mimosaConfig, options, next) {
  var hasFiles, _ref;
  hasFiles = ((_ref = options.files) != null ? _ref.length : void 0) > 0;
  if (!hasFiles) {
    return next();
  }
  _(options.files).each(function(file) {
    var fileAnalysis, relName, shim;
    relName = path.relative(amdify.path, file.inputFileName);
    shim = shims.filter(function(pair) {
      return pair[0] === relName;
    }).map(function(pair) {
      return pair[1];
    }).first() || {};
    fileAnalysis = jshintResults[shim.name || relName];
    if (fileAnalysis) {
      fileAnalysis.shim.deps = _(fileAnalysis.shim.deps || []).map(function(dep) {
        if (jshintResults[dep]) {
          return [dep, jshintResults[dep]];
        }
      }).filter().value();
      fileAnalysis.deps = _(fileAnalysis.deps).map(function(dep) {
        return [dep, amdify.globals[dep]];
      }).filter().value();
      return file.outputFileText = _wrap(file, fileAnalysis, mimosaConfig.amdify);
    }
  });
  return next();
};

_wrap = function(file, fileAnalysis, amdify) {
  var exports, funcStart, imports, start;
  start = "define( " + (_(fileAnalysis.deps).map(function(item) {
    return item[1];
  }).join(',')) + "," + (_(fileAnalysis.shim.deps).map(function(item) {
    return item[0];
  }));
  funcStart = ",function( " + (_(fileAnalysis.deps).map(function(item) {
    return item[0];
  }).join(',')) + ", " + (_(fileAnalysis.shim.deps).map(function(val, index) {
    return '__amdify__' + index;
  }).join(',')) + " ){";
  imports = _(fileAnalysis.shim.deps).map(function(val, index) {
    return _(val[1].exports).map(function(exp) {
      if (exp.length > 1) {
        return _(exp).intersect(fileAnalysis.deps).map(function(common) {
          return "var " + common + " = __amdify__" + index + "." + common + ";";
        });
      } else if (exp.length === 1) {
        return _(exp).intersect(fileAnalysis.deps).map(function(common) {
          return "var " + common + " = __amdify__" + index;
        });
      }
    }).flatten().value();
  }).flatten().join('\n');
  if (fileAnalysis.exports.length > 1) {
    exports = "return { " + (_(fileAnalysis.exports).map(function(exp) {
      return exp + ':' + exp;
    }).join(',')) + " };";
  } else if (fileAnalysis.exports.length === 1) {
    exports = "return " + (_.first(fileAnalysis.exports));
  }
  return "" + start + funcStart + "\n" + imports + "\n" + file.outputFileText + "\n" + exports + "\n});";
};

module.exports = {
  registration: registration,
  defaults: config.defaults,
  placeholder: config.placeholder,
  validate: config.validate
};
