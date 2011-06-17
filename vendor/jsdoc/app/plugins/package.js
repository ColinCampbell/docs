/*globals JSDOC */

(function() {
  var retrievePackage = function(name) {
    var len = JSDOC.packages.length,
        idx;

    if (name === undefined || name === null) { name = "Global"; }

    for (idx = 0; idx < len; idx++) {
      if (JSDOC.packages[idx] && JSDOC.packages[idx].name === name) {
        return JSDOC.packages[idx];
      }
    }

    JSDOC.packages.push({name: name, classes: []});
    return JSDOC.packages[JSDOC.packages.length - 1];
  };

  var retrievePackageByFolder = function(folder) {
    var len = JSDOC.packages.length,
        idx;

    for (idx = 0; idx < len; idx++) {
      if (JSDOC.packages[idx] && JSDOC.packages[idx].folder === folder) {
        return JSDOC.packages[idx];
      }
    }

    JSDOC.packages.push({name: name, folder: folder, classes: []});
    return JSDOC.packages[JSDOC.packages.length - 1];
  };

  var getPackageId = function(symbol) {
    var file = symbol.srcFile,
        p = file ? file.match(/packages\/([A-Za-z\-]*)/) : null;

    p = p ? p[1] : null;
    return p;
  };

  JSDOC.usePackages = false;
  JSDOC.packages = [];

  JSDOC.PluginManager.registerPlugin("JSDOC.package", {
      onInit: function(opts) {
        var packages = opts.packages;

        if (packages) {
          for (var idx = 0; idx < packages.length; idx++) {
            packages[idx].classes = [];
          }

          JSDOC.packages = packages;
          JSDOC.usePackages = true;
        }
      },
      onSymbol: function(symbol) {
        if (!JSDOC.usePackages) { return; }

        var name = getPackageId(symbol), p;

        if (name) {
          // we found a package name
          if (p = retrievePackageByFolder(name)) {
            name = p.name;
          }
        }

        symbol.packageName = name;
      },
      onFinishedParsing: function(symbolSet) {
        if (!JSDOC.usePackages) { return; }

        var symbols = symbolSet.toArray(),
            p, symbol, isClass, i, l;

        function isaClass($) {return ($.is("CONSTRUCTOR") || $.isNamespace); }
        function sortByName(a, b) {
          if (a.alias !== undefined && b.alias !== undefined) {
            a = a.alias.toLowerCase();
            b = b.alias.toLowerCase();
            if (a < b) { return -1; }
            if (a > b) { return 1; }
            return 0;
          }
        }

        for (i = 0, l = symbols.length; i < l; i++) {
          symbol = symbols[i];

          if (isaClass(symbol)) {
            p = retrievePackage(symbol.packageName);
            p.classes.push(symbol);
          }
        }

        for (i = 0, l = JSDOC.packages.length; i < l; i++) {
          JSDOC.packages[i].classes.sort(sortByName);
        }
      }
    }
  );
  
})();
