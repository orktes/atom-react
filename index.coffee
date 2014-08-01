path   = require("path")
docblock = require('jstransform/src/docblock')

# use same docblock parser as jsxtransformer does
isJSX = (text) ->
  doc = docblock.parse text;
  for b in doc
    return true if b[0] == 'jsx'
  false

module.exports = activate: () ->
  atom.workspace.eachEditor (editor) ->
    if path.extname(editor.getPath()) is ".jsx" or isJSX(editor.getText())
      jsxGrammar = atom.syntax.grammarsByScopeName["source.js.jsx"]
      editor.setGrammar jsxGrammar if jsxGrammar
