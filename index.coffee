path   = require 'path'
docblock = require 'jstransform/src/docblock'

{Subscriber} = require 'emissary'
{OnigRegExp} = require 'oniguruma'

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
      decreaseNextLineIndentRegex = self.decreaseNextLineIndentRegex(editor)
      decreaseIndentRegex = @decreaseIndentRegexForScopeDescriptor(scopeDescriptor)
      increaseIndentRegex = @increaseIndentRegexForScopeDescriptor(scopeDescriptor)

      precedingRow = bufferRow - 1

      return if precedingRow < 0

      precedingLine = @buffer.lineForRow(precedingRow)
      if decreaseNextLineIndentRegex.testSync(precedingLine) and
         not (increaseIndentRegex and increaseIndentRegex.testSync(precedingLine))
        console.log("Should decrease indent for line")
        currentIndentLevel = @editor.indentationForBufferRow(precedingRow)
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
      return indent unless editor.getGrammar().scopeName == "source.js.jsx"

      scopeDescriptor = @editor.scopeDescriptorForBufferPosition([bufferRow, 0])
      decreaseNextLineIndentRegex = self.decreaseNextLineIndentRegex(editor)
      increaseIndentRegex = @increaseIndentRegexForScopeDescriptor(scopeDescriptor)
      precedingRow = bufferRow - 1


      return indent if precedingRow < 0

      precedingLine = @buffer.lineForRow(precedingRow)
      while precedingRow > 1 and not precedingLine.trim()
        precedingRow -= 1
        precedingLine = @buffer.lineForRow(precedingRow)

      #indent += 1 if increaseIndentRegex.testSync(precedingLine);
      console.log(precedingLine,indent)
      indent -= 1 if decreaseNextLineIndentRegex.testSync(precedingLine)
      console.log(precedingLine,indent)

      return Math.max(indent, 0)

  patchEditorLangMode: (editor) ->
    @patchEditorLangModeSuggestedIndentForBufferRow(editor)
    @patchEditorLangModeAutoDecreaseIndentForBufferRow(editor)

  decreaseNextLineIndentRegex: (editor) ->
    new OnigRegExp('/>\\s*$')

  activate: ->
    # Patch edtiors language mode to get proper indention
    @patchEditorLangMode(editor) for editor in atom.workspace.getTextEditors()

    @subscribe atom.workspace.onDidAddTextEditor (event) =>
      editor = event.textEditor

      @patchEditorLangMode(editor)

      # Check if file extension is .jsx or the file has the old JSX notation
      if path.extname(editor.getPath()) is ".jsx" or isJSX(editor.getText())
        jsxGrammar = atom.syntax.grammarsByScopeName["source.js.jsx"]
        editor.setGrammar jsxGrammar if jsxGrammar


module.exports = new AtomReact
