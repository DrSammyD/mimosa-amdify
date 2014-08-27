mimosa-amdify
===========

## Overview

This is a Mimosa module for wrapping browser code written in requirejs define module.  This is an external module and does not come by default with Mimosa.

This module provides RequireJS and AMD for non AMD vendor javascript files.  So if you use non AMD modules which polute your global namespace and don't return anything for their defines, but want to use them as AMD files and take advantage of all that RequireJS' configuration allows you, like, among other things, creating module path shortcuts and aliases, then this is the module for you.

Stated differently, this module allows you to use non-AMD vendor scripts as AMD modules, and can shim other files to use those modules even if they aren't also amd modules.

Because this module still leverages AMD/RequireJS, this will only run when the modules are being copied to the public folder, so it will still take advantage of all of the functionality provided by the `mimosa-require` module, like <a href="http://mimosa.io/utilities.html#requirejs">path verification, and circular dependency checking</a> and <a href="http://mimosa.io/optimization.html#require">on-the-fly optimization</a> if your entire application.

For more information regarding Mimosa, see http://mimosa.io

## Usage

Add `'amdify'` to your list of modules.  That's all!  Mimosa will install the module for you when you start up.

If you are using `"use strict"` in your code, and you are using the `mimosa-lint` module, you'll want to make sure that in your list of modules, `amdify` comes before `lint`. If it comes after `mimosa-lint`, then `mimosa-lint` may complain about certain objects not being available that are provided by the `amdify` module.

## Functionality

The `'amdify'` module will wrap your JavaScript code with the <a href="http://requirejs.org/docs/api.html#cjsmodule">define wrapper</a> that RequireJS understands.

The module performs this wrapping during the `afterCompile` step of the `buildFile`, `add` and `update` Mimosa workflows.  Which simply means whenever JavaScript is compiled or copied, post-compilation the wrapper is applied.  For JavaScript the wrapper is added to the raw JavaScript code before it is written, and for something like CoffeeScript, it is added to the compiled JavaScript.

The module will not wrap files that it determines are already wrapped in a `define` block. This wrapper will also export any globals created inside of your file, and import any implied globals in the define function based on your globals in the config file.  See config below.

## Default Config

```
amdify:
  path: './assets/javascripts/app/'
  envVars: ['browser','ecmaIdentifiers','reservedVars']
  globals: {'jquery':['jQuery','$']}
```

* 'path' : this is a path from the root of the project to you requirejs mainConfig file. It's used to determine how files are required by other files wrapped by this plugin

* 'envVars': an array of strings which represent jshint environment variables. These are globals that won't be exported even though jshint thinks they are globals. See [jshint vars.js file](https://github.com/jshint/jshint/blob/master/src/vars.js) for more about which variables are excluded. only the keys are working right now. will add further integration at a future date.

* 'globals': this object defines which globals if found will be added to the dependencies of the define function. For example, if jshint finds that the file uses either the global `jQuery` or `$`, the define add the key `jquery` to the dependencies list. This requires you to alias `jquery` in your requirejs config but the key `jquery` could have just as easily been `../vendor/jquery/jquery.js`

## Other options
```
  shim:
    globals:{ fastclick':['FastClick'] }
    '../vendor/foundation/foundation.js':
      name:'foundation'
    '../vendor/foundation/foundation.alert.js'
      deps:['foundation']
```
Foundation is one of the classic examples of a big library which doesn't use AMD. It has a large plugin framework too, and it depends on jQuery. It also depends on a library called fastclick. we've regesterd fastclick as a global that if is found as an implied global in any file, it will be added to the define dependency list for the file we're modularizing. It can even find `window.FastClick`, and `window['FastClick']`. Be wary though, it can't find  `var x = 'FastClick'; window[x]`

foundation.alert.js does depend on foundation.js, and we've specified that in the shim. Any global inside of foundation.js will be declared as a `var` and will be gotten from the exports created during the jshint of foundation.js. If only one global is found it will be exported directly, otherwise it will be on an export function. as it happens foundation.js only exports a single global `Foundation`

So our generated code will look like this

foundation.js
```
define(['fastclick'],function(FastClick){
	/*the rest of our foundation.alert.js file
	return Foundation	
})
```
foundation.alert.js
```
define(['foundation'],function(__amdify__1 ){
	var Foundation = __amdify__1
	/*the rest of our foundation.alert.js file
})
```

If how ever Foundation exported another global, say `Bootstrap`, it would generate this
foundation.js
```
define(['fastclick'],function(FastClick){
	/*the rest of our foundation.alert.js file
	return {Foundation:Foundation,Bootstrap:Bootstrap}
})
```
foundation.alert.js
```
define(['foundation'],function(__amdify__1 ){
	var Foundation = __amdify__1.Foundation;
	/*the rest of our foundation.alert.js file
})
```
If foundation.alert.js used the implied global `Bootstrap` it would have also assigned `var Bootstrap = __amdify__1.Bootstrap;`

Note: If name isn't supplied, the path to the file will be used by any shimmed files

Much of this can be avoided if you know that both your main file and plugins will only use one export
```
  shim:
    globals:{ fastclick:['FastClick'], foundation: ['Foundation']}
    '../vendor/foundation/foundation.js':
      name:'foundation'
```
Now foundation.alert.js will know about the impled global variable "Foundation", and will simply require 'foundation'. If you want to export only a single global you can do the following
```
  shim:
    globals:{ fastclick:['FastClick'], foundation: ['Foundation']}
    '../vendor/foundation/foundation.js':
      name:'foundation'
      export:'Foundation'
```
This will force a single global to be exported. I'd be careful with this, as it hides globals and may break some of the shimmed files depending on those globals. Another way to do this is to create another module which requires this module, then returns the single export you desire, and then use [requirejs's map configuration ](https://github.com/dbashford/AngularFunMimosaCommonJS) to determine which dependents get's what module

baseFoundation.js
```
define(['foundation'],function(exportedFromAllGlobalsInFoundation){
	return exportedFromAllGlobalsInFoundation.Foundation
})

require.config({map:'../vendor/foundation/*':{'foundation':'foundation'},'*':{'foundation':'baseFoundation'})
```
## Example

The [AngularFunMimosaCommonJS](https://github.com/dbashford/AngularFunMimosaCommonJS) project is a working example of a project that uses Mimosa and CommonJS.  Check it out.  Hopefully it'll answer any questions you have.
