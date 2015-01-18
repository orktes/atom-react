path   = require 'path'
{Subscriber} = require 'emissary'

# use same docblock parser as jsxtransformer does
isJSX = (text) ->
  docblock = require 'jstransform/src/docblock'
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

  onReformat: ->
    jsxformat = require 'jsxformat'
    _ = require 'lodash'

    editor = atom.workspace.getActiveEditor()
    selections = editor.getSelections()

    for selection in selections
      try
        jsxformat.setOptions({});
        result = jsxformat.format(selection.getText())
        selection.insertText(result, {autoIndent: true});
      catch err
        # Parsing/formatting the selection failed lets try to parse the whole file but format the selection only
        range = selection.getBufferRange().serialize()
        # esprima ast line count starts for 1
        range[0][0]++
        range[1][0]++

        jsxformat.setOptions({range: range});

        # TODO: use fold
        original = editor.getText();

        try
          result = jsxformat.format(original)
          selection.clear()

          originalLineCount = editor.getLineCount()
          editor.setText(result)
          newLineCount = editor.getLineCount()

          firstChangedLine = range[0][0] - 1
          lastChangedLine = range[1][0] - 1 + (newLineCount - originalLineCount)

          if lastChangedLine > firstChangedLine
            for row in [firstChangedLine...(lastChangedLine + 1)]
              editor.autoIndentBufferRow(row)

          # return back
          editor.setCursorBufferPosition([firstChangedLine, range[0][1]])


  processEditor: (editor) ->
    @patchEditorLangMode(editor)
    @autoSetGrammar(editor)

  activate: ->
    jsxTagStartPattern = '(?x)((^|=|return)\\s*<([^!/?](?!.+?(</.+?>))))'
    jsxComplexAttributePattern = '(?x)\\{ [^}"\']* $|\\( [^)"\']* $'
    decreaseIndentForNextLinePattern = '/>\\s*,?\\s*$'

    atom.config.set("react.jsxTagStartPattern", jsxTagStartPattern)
    atom.config.set("react.jsxComplexAttributePattern", jsxComplexAttributePattern)
    atom.config.set("react.decreaseIndentForNextLinePattern", decreaseIndentForNextLinePattern)

    # Bind events
    atom.workspaceView.command 'react:reformat', @onReformat;

    # Patch edtiors language mode to get proper indention
    @processEditor(editor) for editor in atom.workspace.getTextEditors()

    @subscribe atom.workspace.onDidAddTextEditor (event) =>
      editor = event.textEditor
      @processEditor(editor)


module.exports = new AtomReact
