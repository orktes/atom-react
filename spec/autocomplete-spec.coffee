describe "Tag autocomplete tests", ->
  [editor, buffer, languageMode] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage("react")

    waitsForPromise ->
        atom.workspace.open("foofoo", autoIndent: false).then (o) ->
          editor = o
          {buffer, languageMode} = editor
          grammar = atom.grammars.grammarForScopeName("source.js.jsx")
          editor.setGrammar(grammar);

    afterEach ->
      atom.packages.deactivatePackages()
      atom.packages.unloadPackages()

  describe "tag handling", ->
    it "should autocomplete tag", ->
      editor.insertText('<p>')
      expect(editor.getText()).toBe('<p></p>')

    it "should remove closing tag", ->
      editor.insertText('<p>')
      expect(editor.getText()).toBe('<p></p>')
      editor.backspace()
      expect(editor.getText()).toBe('<p')

    it "should add extra line break when new line added between open and close tag", ->
      editor.insertText('<p></p>')
      editor.setCursorBufferPosition([0,3])
      editor.insertText('\n')
      expect(editor.buffer.getLines()[0]).toBe('<p>')
      expect(editor.buffer.getLines()[2]).toBe('</p>')
