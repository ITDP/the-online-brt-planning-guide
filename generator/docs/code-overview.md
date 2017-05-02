
## Haxelibs

One manages to see them all (origin and versions) by checking the [dockerfile](https://github.com/ITDP/the-online-brt-planning-guide/blob/master/.robrt.Dockerfile), check the `RUN haxelib` commands 

### ansi
Used for making color in prompt with ANSI escape sequences.
-in https://github.com/SmilyOrg/ansi

### literals:
Tools for commandline output
- so far only one function: `doctrim`
- in https://github.com/protocubo/literals.hx

### sys-utils:
System tools that speed up/simplify calling OS
-  in https://github.com/jonasmalacofilho/sys-utils.hx

### version
> Haxe macros useful for including version strings (version from `haxelib.json`, git commit hash and Haxe version) to a target build.
- in haxelib (https://github.com/ypid/haxe-version)

### utest
unit tests
- in haxelib (https://github.com/fponticelli/utest)
- tests are in /src/tests
- entrance in RunAll (.hx) with a main function when standing alone
 -- main calls runAll function that calls each of of others
(-- NeedleManWunchTests are in `generator/include/`

* there is the class ` utest.Assert` here to be used while testing: `Assert.same(,)` or  `Assert.equal( )`  not to be mistaken with `Assertion.assert` that is from the library bellow

### assertion: 
Does checks in runtime 
- in https://github.com/protocubo/assertion.hx
- Assertion.assert(condition) throws an error if fails
- Assertion.weakAssert(condition) traces (log) if failed
//defined (s:String):Bool supposedly "Tells if compiler directive s has been set."
//
// and "Compiler directives are set using the -D command line parameter, or by calling `haxe.macro.Compiler.define.`.
//
// Although the use in assertion lib seems to check if var exists

### tink_template:
It concatenates text output with haxe code in the same file (with extension `tt`)
- in haxe lib (https://github.com/haxetink/tink_template)
- by marking one field @template (e.g. `@:template function renderBreadcrumbs(bcs:Breadcrumbs);`) the return is the file with the same name (i.e. `renderHead`) but processing the code mixed inside `(: :)`being the code.
-- [fields can also be declared inside `tt` s, the file is seen as a class file, but we are not using here it thus far]

### hxnodejs
Haxe code will be converted to Javascript, the haxenodejs is a library for integration with Node: an environment for running Javascript on server side.
- in haxelib

### hxparse
Is the library that provides the tool to create the "language" will be used in the source `.manu` files
- waiting pull requests in haxelib version, for now in  https://github.com/jonasmalacofilho/hxparse 


Generator:

function `saveSource` returns the id for a given source element
srcCache, lastSrcId, saveSource


