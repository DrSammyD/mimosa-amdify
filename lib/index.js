"use strict";
var amdify, clean, config, defineRegex, envVars, globalsRegex, globalsUsageReggex, jsh, jshintResults, logger, path, registration, reqEnvVars, shims, stripCommentsRegex, track, _, _analizeFiles, _applyRequireJSWrapper, _setJshintResult, _wrap,
  __slice = [].slice;

config = require('./config');

track = require('./track');

clean = require('./clean');

jsh = require('jshint');

_ = require('lodash');

path = require('path');

stripCommentsRegex = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg;

defineRegex = /(?:^\s*|[}{\(\);,\n\?\&]\s*)define\s*\(\s*("[^"]+"\s*,\s*|'[^']+'\s*,\s*)?\s*(\[(\s*(("[^"]+"|'[^']+')\s*,|\/\/.*\r?\n|\/\*(.|\s)*?\*\/))*(\s*("[^"]+"|'[^']+')\s*,?\s*)?(\s*(\/\/.*\r?\n|\/\*(.|\s)*?\*\/)\s*)*\]|function\s*|{|[_$a-zA-Z\xA0-\uFFFF][_$a-zA-Z0-9\xA0-\uFFFF]*\))/g;

globalsRegex = ["window(\\.|\\[[\\\"\\\'])", "([\\\"\\\']\\])?\\s*?="];

globalsUsageReggex = ["window(\\.|\\[[\\\"\\\'])", "([\\\"\\\']\\])?"];

logger = null;

reqEnvVars = _(require.cache).pairs().filter(function(item) {
  return item[0].indexOf('vars.js') !== -1 && item[1].parent.id.indexOf('jshint.js') !== -1;
}).map(function(item) {
  return item[1].exports;
}).first();

envVars = [];

jshintResults = {};

shims = null;

amdify = null;

registration = function(mimosaConfig, register) {
  logger = mimosaConfig.log;
  amdify = mimosaConfig.amdify;
  envVars = _(reqEnvVars).pairs().filter(function(vars) {
    return _(amdify.envVars).contains(vars[0]);
  }).map(function(vars) {
    return _.keys(vars[1]);
  }).flatten().value();
  amdify.globals = _(amdify.globals).map(function(val, key) {
    return _(val).map(function(item) {
      return [item, key];
    }).value();
  }).flatten(true).object().value();
  shims = _(amdify.shim).pairs();
  jshintResults = track.getPreviousAnalyzedFileList(mimosaConfig);
  register(['add', 'update', 'buildFile'], 'read', _analizeFiles, __slice.call(mimosaConfig.extensions.javascript));
  return register(['add', 'update', 'buildExtension'], 'beforeWrite', _applyRequireJSWrapper, __slice.call(mimosaConfig.extensions.javascript));
};

_setJshintResult = function(file, shim, relName) {
  var result, text;
  jsh.JSHINT(file.inputFileText, {
    undef: true,
    predef: envVars
  });
  result = {
    shim: shim
  };
  result.replacements = [];
  result.usage = [];
  text = file.inputFileText;
  _(jsh.JSHINT.data().implieds).pluck('name').difference(envVars).concat(_.flatten([shim["export"] || []])).each(function(implied) {
    var glreg;
    glreg = new RegExp(globalsRegex[0] + implied + globalsRegex[1], 'g');
    if (text.replace(stripCommentsRegex, '').match(glreg)) {
      result.replacements.push(implied);
      return text = "var " + implied + "; " + (text.replace(glreg, implied + '='));
    }
  });
  _(amdify.globals).keys().each(function(global) {
    var glreg;
    glreg = new RegExp(globalsUsageReggex[0] + global + globalsUsageReggex[1], 'g');
    if (text.replace(stripCommentsRegex, '').match(glreg) && !text.match(/var\s+?window[\W]/)) {
      result.usage.push(global);
      return text = text.replace(glreg, global);
    }
  });
  jsh.JSHINT(text);
  file = result;
  file.deps = _(jsh.JSHINT.data().implieds).pluck('name').difference(envVars).value();
  file.exports = file.shim["export"] ? _.flatten([file.shim["export"]]) : _(jsh.JSHINT.data().globals).difference(envVars).filter(function(item) {
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
  _(options.files).filter(function(file) {
    var maybe;
    maybe = _([amdify.includePaths]).flatten().map(function(include) {
      var relative;
      relative = path.relative(path.relative(amdify.path, file.inputFileName), include);
      if (!_(relative.split("/")).filter(function(item) {
        return item !== "..";
      }).value().length) {
        return relative.match(/\.\./g);
      } else if (relative === '') {
        return [];
      } else {
        return null;
      }
    }).filter(function(include) {
      return include || include === 0;
    }).map(function(item) {
      return item.length;
    });
    return (_([amdify.excludePaths]).flatten().map(function(exclude) {
      var relative;
      relative = path.relative(path.relative(amdify.path, file.inputFileName), exclude);
      if (!_(relative.split("/")).filter(function(item) {
        return item !== "..";
      }).value().length) {
        return relative.match(/\.\./g);
      } else if (relative === '') {
        return [];
      } else {
        return null;
      }
    }).filter().map(function(item) {
      return item.length;
    }).min().value() >= maybe.min().value()) && (maybe.value().length || !amdify.includePaths.length);
  }).each(function(file) {
    var relName, shim;
    if (file.inputFileText.match(defineRegex)) {
      if (logger.isDebug()) {
        return logger.debug("Not wrapping [[ " + file.inputFileName + " ]], it already contains a define block");
      }
    } else {
      relName = path.relative(amdify.path, file.inputFileName);
      shim = shims.filter(function(pair) {
        return pair[0] === relName;
      }).map(function(pair) {
        return pair[1];
      }).first() || {};
      return _setJshintResult(file, shim, relName);
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
  _(fileAnalysis.replacements).each(function(implied) {
    var glreg;
    glreg = new RegExp(globalsRegex[0] + implied + globalsRegex[1], 'g');
    return file.outputFileText = "var " + implied + "; " + (file.outputFileText.replace(glreg, implied + '='));
  });
  _(fileAnalysis.usage).each(function(global) {
    var glreg;
    glreg = new RegExp(globalsUsageReggex[0] + global + globalsUsageReggex[1], 'g');
    return file.outputFileText = file.outputFileText.replace(glreg, global);
  });
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
