path   = require 'path'
docblock = require 'jstransform/src/docblock'

{Subscriber} = require 'emissary'

# use same docblock parser as jsxtransformer does
isJSX = (text) ->
  doc = docblock.parse text;
  for b in doc
    return true if b[0] == 'jsx'
  false

class AtomReact
  Subscriber.includeInto(this)
  constructor: ->
  patchEditorLangModeAutoDecreaseIndentForBufferRow: (editor) ->
    self = this
    fn = editor.languageMode.autoDecreaseIndentForBufferRow
    editor.languageMode.autoDecreaseIndentForBufferRow = (bufferRow, options) ->
      return fn.call(editor.languageMode, bufferRow, options) unless editor.getGrammar().scopeName == "source.js.jsx"

      scopeDescriptor = @editor.scopeDescriptorForBufferPosition([bufferRow, 0])
      decreaseNextLineIndentRegex = @getRegexForProperty(scopeDescriptor, 'react.decreaseIndentForNextLinePattern')
      decreaseIndentRegex = @decreaseIndentRegexForScopeDescriptor(scopeDescriptor)
      increaseIndentRegex = @increaseIndentRegexForScopeDescriptor(scopeDescriptor)

      precedingRow = @buffer.previousNonBlankRow(bufferRow)

      return if precedingRow < 0

      precedingLine = @buffer.lineForRow(precedingRow)
      line = @buffer.lineForRow(bufferRow)

      if precedingLine and decreaseNextLineIndentRegex.testSync(precedingLine) and
         not (increaseIndentRegex and increaseIndentRegex.testSync(precedingLine))
        currentIndentLevel = @editor.indentationForBufferRow(precedingRow)
        currentIndentLevel -= 1 if decreaseIndentRegex and decreaseIndentRegex.testSync(line)
        desiredIndentLevel = currentIndentLevel - 1
        if desiredIndentLevel >= 0 and desiredIndentLevel < currentIndentLevel
          @editor.setIndentationForBufferRow(bufferRow, desiredIndentLevel)
      else
        fn.call(editor.languageMode, bufferRow, options)

  patchEditorLangModeSuggestedIndentForBufferRow: (editor) ->
    self = this
    fn = editor.languageMode.suggestedIndentForBufferRow
    editor.languageMode.suggestedIndentForBufferRow = (bufferRow, options) ->
      indent = fn.call(editor.languageMode, bufferRow, options)
      return indent unless editor.getGrammar().scopeName == "source.js.jsx" and bufferRow > 1

      scopeDescriptor = @editor.scopeDescriptorForBufferPosition([bufferRow, 0])
      decreaseNextLineIndentRegex = @getRegexForProperty(scopeDescriptor, 'react.decreaseIndentForNextLinePattern')
      increaseIndentRegex = @increaseIndentRegexForScopeDescriptor(scopeDescriptor)
      tagStartRegex = @getRegexForProperty(scopeDescriptor, 'react.jsxTagStartPattern')
      complexAttributeRegex = @getRegexForProperty(scopeDescriptor, 'react.jsxComplexAttributePattern')

      precedingRow = @buffer.previousNonBlankRow(bufferRow)

      return indent if precedingRow < 0

      precedingLine = @buffer.lineForRow(precedingRow)
      
      return indent if not precedingLine?

      indent += 1 if tagStartRegex.testSync(precedingLine) and complexAttributeRegex.testSync(precedingLine)
      indent -= 1 if precedingLine and decreaseNextLineIndentRegex.testSync(precedingLine)

      return Math.max(indent, 0)

  patchEditorLangMode: (editor) ->
    @patchEditorLangModeSuggestedIndentForBufferRow(editor)
    @patchEditorLangModeAutoDecreaseIndentForBufferRow(editor)

  autoSetGrammar: (editor) ->
    # Check if file extension is .jsx or the file has the old JSX notation
    if path.extname(editor.getPath()) is ".jsx" or isJSX(editor.getText())
      jsxGrammar = atom.syntax.grammarsByScopeName["source.js.jsx"]
      editor.setGrammar jsxGrammar if jsxGrammar

  activate: ->
    jsxTagStartPattern = '(?x)((^|=|return)\\s*<([^!/?](?!.+?(</.+?>))))'
    jsxComplexAttributePattern = '(?x)\\{ [^}"\']* $|\\( [^)"\']* $'
    decreaseIndentForNextLinePattern = '/>\\s*,?\\s*$'

    atom.config.set("react.jsxTagStartPattern", jsxTagStartPattern)
    atom.config.set("react.jsxComplexAttributePattern", jsxComplexAttributePattern)
    atom.config.set("react.decreaseIndentForNextLinePattern", decreaseIndentForNextLinePattern)

    # Patch edtiors language mode to get proper indention
    @patchEditorLangMode(editor) for editor in atom.workspace.getTextEditors()
    @autoSetGrammar(editor) for editor in atom.workspace.getTextEditors()

    @subscribe atom.workspace.onDidAddTextEditor (event) =>
      editor = event.textEditor

      @patchEditorLangMode(editor)
      @autoSetGrammar(editor)




module.exports = new AtomReact
