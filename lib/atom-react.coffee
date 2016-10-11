{CompositeDisposable, Disposable} = require 'atom'

contentCheckRegex = null
defaultDetectReactFilePattern = '/((require\\([\'"]react(?:(-native|\\/addons))?[\'"]\\)))|(import\\s+[\\w{},\\s]+\\s+from\\s+[\'"]react(?:(-native|\\/addons))?[\'"])/'
autoCompleteTagStartRegex = /(<)([a-zA-Z0-9\.:$_]+)/g
autoCompleteTagCloseRegex = /(<\/)([^>]+)(>)/g

jsxTagStartPattern = '(?x)((^|=|return)\\s*<([^!/?](?!.+?(</.+?>))))'
jsxComplexAttributePattern = '(?x)\\{ [^}"\']* $|\\( [^)"\']* $'
decreaseIndentForNextLinePattern = '(?x)
/>\\s*(,|;)?\\s*$
| ^\\s*\\S+.*</[-_\\.A-Za-z0-9]+>$'

class AtomReact
  config:
    enabledForAllJavascriptFiles:
      type: 'boolean'
      default: false
      description: 'Enable grammar, snippets and other features automatically for all .js files.'
    disableAutoClose:
      type: 'boolean'
      default: false
      description: 'Disabled tag autocompletion'
    detectReactFilePattern:
      type: 'string'
      default: defaultDetectReactFilePattern
    jsxTagStartPattern:
      type: 'string'
      default: jsxTagStartPattern
    jsxComplexAttributePattern:
      type: 'string'
      default: jsxComplexAttributePattern
    decreaseIndentForNextLinePattern:
      type: 'string'
      default: decreaseIndentForNextLinePattern

  constructor: ->
  patchEditorLangModeAutoDecreaseIndentForBufferRow: (editor) ->
    self = this
    fn = editor.languageMode.autoDecreaseIndentForBufferRow
    return if fn.jsxPatch

    editor.languageMode.autoDecreaseIndentForBufferRow = (bufferRow, options) ->
      return fn.call(editor.languageMode, bufferRow, options) unless editor.getGrammar().scopeName == "source.js.jsx"

      scopeDescriptor = @editor.scopeDescriptorForBufferPosition([bufferRow, 0])
      decreaseNextLineIndentRegex = @cacheRegex(decreaseIndentForNextLinePattern)
      decreaseIndentRegex = @decreaseIndentRegexForScopeDescriptor(scopeDescriptor)
      increaseIndentRegex = @increaseIndentRegexForScopeDescriptor(scopeDescriptor)

      precedingRow = @buffer.previousNonBlankRow(bufferRow)

      return if precedingRow < 0

      precedingLine = @buffer.lineForRow(precedingRow)
      line = @buffer.lineForRow(bufferRow)

      if precedingLine and decreaseNextLineIndentRegex.testSync(precedingLine) and
         not (increaseIndentRegex and increaseIndentRegex.testSync(precedingLine)) and
         not @editor.isBufferRowCommented(precedingRow)
        currentIndentLevel = @editor.indentationForBufferRow(precedingRow)
        currentIndentLevel -= 1 if decreaseIndentRegex and decreaseIndentRegex.testSync(line)
        desiredIndentLevel = currentIndentLevel - 1
        if desiredIndentLevel >= 0 and desiredIndentLevel < currentIndentLevel
          @editor.setIndentationForBufferRow(bufferRow, desiredIndentLevel)
      else if not @editor.isBufferRowCommented(bufferRow)
        fn.call(editor.languageMode, bufferRow, options)

  patchEditorLangModeSuggestedIndentForBufferRow: (editor) ->
    self = this
    fn = editor.languageMode.suggestedIndentForBufferRow
    return if fn.jsxPatch

    editor.languageMode.suggestedIndentForBufferRow = (bufferRow, options) ->
      indent = fn.call(editor.languageMode, bufferRow, options)
      return indent unless editor.getGrammar().scopeName == "source.js.jsx" and bufferRow > 1

      scopeDescriptor = @editor.scopeDescriptorForBufferPosition([bufferRow, 0])

      decreaseNextLineIndentRegex = @cacheRegex(decreaseIndentForNextLinePattern)
      increaseIndentRegex = @increaseIndentRegexForScopeDescriptor(scopeDescriptor)

      decreaseIndentRegex = @decreaseIndentRegexForScopeDescriptor(scopeDescriptor)
      tagStartRegex = @cacheRegex(jsxTagStartPattern)
      complexAttributeRegex = @cacheRegex(jsxComplexAttributePattern)

      precedingRow = @buffer.previousNonBlankRow(bufferRow)

      return indent if precedingRow < 0

      precedingLine = @buffer.lineForRow(precedingRow)

      return indent if not precedingLine?

      if @editor.isBufferRowCommented(bufferRow) and @editor.isBufferRowCommented(precedingRow)
        return @editor.indentationForBufferRow(precedingRow)

      tagStartTest = tagStartRegex.testSync(precedingLine)
      decreaseIndentTest = decreaseIndentRegex.testSync(precedingLine)

      indent += 1 if tagStartTest and complexAttributeRegex.testSync(precedingLine) and not @editor.isBufferRowCommented(precedingRow)
      indent -= 1 if precedingLine and not decreaseIndentTest and decreaseNextLineIndentRegex.testSync(precedingLine) and not @editor.isBufferRowCommented(precedingRow)

      return Math.max(indent, 0)

  patchEditorLangMode: (editor) ->
    @patchEditorLangModeSuggestedIndentForBufferRow(editor)?.jsxPatch = true
    @patchEditorLangModeAutoDecreaseIndentForBufferRow(editor)?.jsxPatch = true

  isReact: (text) ->
    return true if atom.config.get('react.enabledForAllJavascriptFiles')


    if not contentCheckRegex?
      match = (atom.config.get('react.detectReactFilePattern') || defaultDetectReactFilePattern).match(new RegExp('^/(.*?)/([gimy]*)$'));
      contentCheckRegex = new RegExp(match[1], match[2])
    return text.match(contentCheckRegex)?

  isReactEnabledForEditor: (editor) ->
    return editor? && editor.getGrammar().scopeName in ["source.js.jsx", "source.coffee.jsx"]

  autoSetGrammar: (editor) ->
    return if @isReactEnabledForEditor editor

    path = require 'path'

    # Check if file extension is .jsx or the file requires React
    extName = path.extname(editor.getPath())
    if extName is ".jsx" or ((extName is ".js" or extName is ".es6") and @isReact(editor.getText()))
      jsxGrammar = atom.grammars.grammarsByScopeName["source.js.jsx"]
      editor.setGrammar jsxGrammar if jsxGrammar

  onHTMLToJSX: ->
    jsxformat = require 'jsxformat'
    HTMLtoJSX = require './htmltojsx'
    converter = new HTMLtoJSX(createClass: false)

    editor = atom.workspace.getActiveTextEditor()

    return if not @isReactEnabledForEditor editor

    selections = editor.getSelections()

    editor.transact =>
      for selection in selections
        try
          selectionText = selection.getText()
          jsxOutput = converter.convert(selectionText)

          try
            jsxformat.setOptions({});
            jsxOutput = jsxformat.format(jsxOutput)

          selection.insertText(jsxOutput);
          range = selection.getBufferRange();
          editor.autoIndentBufferRows(range.start.row, range.end.row)

  onReformat: ->
    jsxformat = require 'jsxformat'
    _ = require 'lodash'

    editor = atom.workspace.getActiveTextEditor()

    return if not @isReactEnabledForEditor editor

    selections = editor.getSelections()
    editor.transact =>
      for selection in selections
        try
          range = selection.getBufferRange();
          serializedRange = range.serialize()
          bufStart = serializedRange[0]
          bufEnd = serializedRange[1]

          jsxformat.setOptions({});
          result = jsxformat.format(selection.getText())

          originalLineCount = editor.getLineCount()
          selection.insertText(result)
          newLineCount = editor.getLineCount()

          editor.autoIndentBufferRows(bufStart[0], bufEnd[0] + (newLineCount - originalLineCount))
          editor.setCursorBufferPosition(bufStart)
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

            editor.autoIndentBufferRows(firstChangedLine, lastChangedLine)

            # return back
            editor.setCursorBufferPosition([firstChangedLine, range[0][1]])

  autoCloseTag: (eventObj, editor) ->
    return if atom.config.get('react.disableAutoClose')

    return if not @isReactEnabledForEditor(editor) or editor != atom.workspace.getActiveTextEditor()

    if eventObj?.newText is '>' and !eventObj.oldText
      # auto closing multiple cursors is a little bit tricky so lets disable it for now
      return if editor.getCursorBufferPositions().length > 1;

      tokenizedLine = editor.tokenizedBuffer?.tokenizedLineForRow(eventObj.newRange.end.row)
      return if not tokenizedLine?

      token = tokenizedLine.tokenAtBufferColumn(eventObj.newRange.end.column - 1)

      if not token? or token.scopes.indexOf('tag.open.js') == -1 or token.scopes.indexOf('punctuation.definition.tag.end.js') == -1
        return

      lines = editor.buffer.getLines()
      row = eventObj.newRange.end.row
      line = lines[row]
      line = line.substr 0, eventObj.newRange.end.column

      # Tag is self closing
      return if line.substr(line.length - 2, 1) is '/'

      tagName = null

      while line? and not tagName?
        match = line.match autoCompleteTagStartRegex
        if match? && match.length > 0
          tagName = match.pop().substr(1)
        row--
        line = lines[row]

      if tagName?
        editor.insertText('</' + tagName + '>', {undo: 'skip'})
        editor.setCursorBufferPosition(eventObj.newRange.end)

    else if eventObj?.oldText is '>' and eventObj?.newText is ''

      lines = editor.buffer.getLines()
      row = eventObj.newRange.end.row
      fullLine = lines[row]

      tokenizedLine = editor.tokenizedBuffer?.tokenizedLineForRow(eventObj.newRange.end.row)
      return if not tokenizedLine?

      token = tokenizedLine.tokenAtBufferColumn(eventObj.newRange.end.column - 1)
      if not token? or token.scopes.indexOf('tag.open.js') == -1
        return
      line = fullLine.substr 0, eventObj.newRange.end.column

      # Tag is self closing
      return if line.substr(line.length - 1, 1) is '/'

      tagName = null

      while line? and not tagName?
        match = line.match autoCompleteTagStartRegex
        if match? && match.length > 0
          tagName = match.pop().substr(1)
        row--
        line = lines[row]

      if tagName?
        rest = fullLine.substr(eventObj.newRange.end.column)
        if rest.indexOf('</' + tagName + '>') == 0
          # rest is closing tag
          serializedEndPoint = [eventObj.newRange.end.row, eventObj.newRange.end.column];
          editor.setTextInBufferRange(
            [
              serializedEndPoint,
              [serializedEndPoint[0], serializedEndPoint[1] + tagName.length + 3]
            ]
          , '', {undo: 'skip'})

    else if eventObj?.newText is '\n'
      lines = editor.buffer.getLines()
      row = eventObj.newRange.end.row
      lastLine = lines[row - 1]
      fullLine = lines[row]

      if />$/.test(lastLine) and fullLine.search(autoCompleteTagCloseRegex) == 0
        while lastLine?
          match = lastLine.match autoCompleteTagStartRegex
          if match? && match.length > 0
            break
          row--
          lastLine = lines[row]

        lastLineSpaces = lastLine.match(/^\s*/)
        lastLineSpaces = if lastLineSpaces? then lastLineSpaces[0] else ''
        editor.insertText('\n' + lastLineSpaces)
        editor.setCursorBufferPosition(eventObj.newRange.end)

  processEditor: (editor) ->
    @patchEditorLangMode(editor)
    @autoSetGrammar(editor)
    disposableBufferEvent = editor.buffer.onDidChange (e) =>
                        @autoCloseTag e, editor

    @disposables.add editor.onDidDestroy => disposableBufferEvent.dispose()

    @disposables.add(disposableBufferEvent);

  deactivate: ->
    @disposables.dispose()
  activate: ->

    @disposables = new CompositeDisposable();


    # Bind events
    disposableConfigListener = atom.config.observe 'react.detectReactFilePattern', (newValue) ->
      contentCheckRegex = null

    disposableReformat = atom.commands.add 'atom-workspace', 'react:reformat-JSX', => @onReformat()
    disposableHTMLTOJSX = atom.commands.add 'atom-workspace', 'react:HTML-to-JSX', => @onHTMLToJSX()
    disposableProcessEditor = atom.workspace.observeTextEditors @processEditor.bind(this)

    @disposables.add disposableConfigListener
    @disposables.add disposableReformat
    @disposables.add disposableHTMLTOJSX
    @disposables.add disposableProcessEditor


module.exports = AtomReact
