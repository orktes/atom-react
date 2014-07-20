path   = require("path")
pragma = /^\s*\/\*\*[\s\*]*@jsx\s*React\.DOM[\s\*]*\*\//

module.exports = activate: () ->
  atom.workspace.eachEditor (editor) ->
    if path.extname(editor.getPath()) is ".jsx" or editor.getText().match(pragma)
      editor.setGrammar atom.syntax.grammarsByScopeName["source.jsx"]
