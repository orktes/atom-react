class TagMacher
  constructor: (editor) ->
    @editor = editor

  lineStartsWithOpeningTag: (bufferRow) ->
    if match = @editor.lineTextForBufferRow(bufferRow).match(/\S/)
      scopeDescriptor = @editor.tokenForBufferPosition([bufferRow, match.index])
      return scopeDescriptor.scopes.indexOf('tag.open.js') > -1 and
             scopeDescriptor.scopes.indexOf('meta.tag.attribute-name.js') == -1

    return false

  lineStartWithAttribute: (bufferRow) ->
    if match = @editor.lineTextForBufferRow(bufferRow).match(/\S/)
      scopeDescriptor = @editor.tokenForBufferPosition([bufferRow, match.index])
      return scopeDescriptor.scopes.indexOf('meta.tag.attribute-name.js') > -1

    return false

  lineStartsWithClosingTag: (bufferRow) ->
    if match = @editor.lineTextForBufferRow(bufferRow).match(/\S/)
      scopeDescriptor = @editor.tokenForBufferPosition([bufferRow, match.index])
      return scopeDescriptor.scopes.indexOf('tag.closed.js') > -1

    return false

module.exports = TagMacher;
