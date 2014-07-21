path   = require("path")
pragma = /^\s*\/\*\*[\s\*]*@jsx\s*React\.DOM[\s\*]*\*\//

module.exports = activate: () ->
  atom.workspace.eachEditor (editor) ->
    if path.extname(editor.getPath()) is ".jsx" or editor.getText().match(pragma)
      jsxGrammar = atom.syntax.grammarsByScopeName["source.js.jsx"]
      editor.setGrammar jsxGrammar if jsxGrammar
